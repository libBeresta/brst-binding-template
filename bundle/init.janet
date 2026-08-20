(use spork/declare-cc)

(import spork/pm)
(import spork/cc)
(import spork/sh)
(import spork/path)
(use spork/cjanet)

# Запустить в какой-то папке с сохранением текущей папки
(defmacro with-cwd
  [target-path & body]
  ~(let [path-back (os/cwd)]
     (os/cd ,target-path)
     ,;body
     (os/cd path-back)))

# Если ничего не указано, считаем, что у нас :release
(when (not (os/getenv "JANET_BUILD_TYPE"))
  (setdyn :build-type :release))

# Многословный режим
(def- is-verbose :flycheck (os/getenv "VERBOSE"))

# Строка _build/release или _build/develop
(def- static-path (string "_build/" (cc/build-type)))

# Забираем info.jdn чтобы не повторяться в declare-project
(def info (-> (slurp "./bundle/info.jdn") parse))

# brst
(def- bundle-name (info :name))

### ================
### Описание проекта
### ================
(declare-project
 :name         (info :name)
 :description  (info :description)
 :version      (info :version)
 :dependencies (info :jpm-dependencies))

# Подгружаем janet-native-tools
(try
  (import janet-native-tools :as jnt)
  ([err fib]
   (print "please run `janet-pm deps` or `jeep prep` first")))

# Подгружаем CMake
(jnt/require-cmake)

# Папка сборки
(def- brst-build-dir (path/join "_build"))

# _build/libbrst.a
(def- brst-build-lib (path/join brst-build-dir
                                     (jnt/gen-static-libname bundle-name)))

(def- brst-cmake-cache (path/join brst-build-dir "CMakeCache.txt"))

# Флаги сборки
(def- cmake-flags @["-B" brst-build-dir "-G" "Ninja"
                    "-DCMAKE_BUILD_TYPE=Release"
                    "-DLIBBRST_SHARED_LIB=OFF"
                    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"])

# Описываем вызов CMake
(def [build-brst-fn clean-brst-fn]
  (jnt/declare-cmake :name "brst"
                     :source-dir "."
                     :build-dir brst-build-dir
                     :cmake-flags cmake-flags
                     :build-type "Release"))

(defn- cmake-cache-line
  [prefix]
  (let [
        cache-data (slurp brst-cmake-cache)
        cache-lines (string/split "\n" cache-data)
        line (filter |(string/has-prefix? prefix $) cache-lines)
       ]
    (when (= (length line) 0)
      (errorf "Something wrong with CMake build. `%s` not found" prefix))
    (let [line1 (line 0)
          line-s (string/split "=" line1)]
       (when (not= (length line-s) 2)
         (errorf "Something wrong with CMake build. `%s` has wrong format [(A=B) expected]." prefix))
       (1 line-s))))

(var cflags (case (os/which)
               :linux @[]))

(def- lflags (case (os/which)
               :linux @[]
               nil))

(build-brst-fn)

(let [source (cmake-cache-line "libbrst_SOURCE_DIR")
      bin    (cmake-cache-line "libbrst_BINARY_DIR")]
  (set cflags @[(string "-I" (path/join source "include")) (string "-I" (path/join bin "include"))]))

(declare-source
  :source [bundle-name])

(declare-native
  :name (path/join bundle-name bundle-name) # brst/brst
  :source @["src/binding.c"]
  :cflags cflags
  :lflags lflags)

#(defn- repack-brst
#  []
#  (case (os/which)
#    :linux (do
#
#             # brst___brst
#             (def- lib-name (string bundle-name "___" bundle-name))
#
#             # brst___brst.a
#             (def- static-arch (string lib-name ".a"))
#
#             # brst___brst.meta.janet
#             (def- meta-name (string lib-name ".meta.janet"))
#
#             # brst.o
#             (def- static-o (string bundle-name ".o"))
#
#             # libbrst.a
#             (def- libfinecurve-arch (jnt/gen-static-libname bundle-name))
#
#             # _build/develop/brst___brst.a
#             (def- static-lib
#               (path/join static-path static-arch))
#
#             # _build/brst-build/libbrst.a
#             (def- static-brst-lib
#               (path/join brst-build-dir libbrst-arch))
#
#             # _build/release/brst.o
#             (def- static-final-o
#               (path/join static-path static-o))
#
#             # _build/release/brst___brst.meta.janet
#             (def- static-meta-name
#               (path/join static-path meta-name))
#
#             (when is-verbose
#               (print (string/format "lib-name: %s" lib-name))
#               (print (string/format "static-arch: %s" static-arch))
#               (print (string/format "meta-name: %s" meta-name) )
#               (print (string/format "static-o: %s" static-o))
#               (print (string/format "libfinecurve-arch: %s" libfinecurve-arch))
#               (print (string/format "static-lib: %s" static-lib))
#               (print (string/format "static-finecurve-lib: %s" static-finecurve-lib))
#               (print (string/format "static-final-o: %s" static-final-o))
#               (print (string/format "static-meta-name: %s" static-meta-name)))
#
#             # Проверяем, что мы уже собрали файл (нужно для повторного билда)
#
#             (with-cwd static-path
#               (sh/exec "ar" "x" static-arch))
#
#             (if (sh/exists? static-final-o)
#
#               (do
#                 (when is-verbose
#                   (print (string "Библиотека `" static-arch "` уже собрана.")))
#                 (sh/rm static-o))
#
#               (do
#                 (when is-verbose
#                   (print (string "Пересобираем `" static-arch "`.")))
#
#                 # Все объектные файлы в библиотеке складываем в один.
#                 # Объединяется результат сборки finecurve и native модуля
#                 (sh/exec "ld" "-r" "-o" static-final-o
#                          "--whole-archive"
#                          static-lib static-brst-lib
#                          "--no-whole-archive")
#
#                 # Удаляем существующий файла native модуля
#                 (sh/rm static-lib)
#
#                 # Архивируем объединенный объектный файл в финальный архив
#                 (sh/exec "ar" "rc" static-lib static-final-o)
#
#                 # Удаляем объектный файл
#                 (sh/rm static-final-o)
#
#                 # Подчищаем meta
#                 (def- meta (slurp static-meta-name))
#
#                 # Удаляем упоминание библиотеки _build/brst-build/libbrst.a
#                 (def- meta-updated
#                   (string/replace (string/format "\"%s\" " brst-build-lib)
#                                   (string/format "# %s\n          " brst-build-lib)
#                                   meta))
#
#                 # Записываем обновленную мету
#                 (spit static-meta-name meta-updated))))))
#

#(defn- build-brst
#  []
#  (build-brst-fn))

#(task "pre-build"  [] (build-brst))
