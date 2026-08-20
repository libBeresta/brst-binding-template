(defparameter +license+
  ";;
;; libBeresta
;;
;; Заголовочные файлы для Janet
;; Дмитрий Соломенников, (с) 2026
;;
")

(defparameter +skip-functions+
  ;; Набор функций, которые предстоит переработать
  ;; для исключения наличия параметров-приемников.
  '("Doc_New_Ex"
    "Doc_New"
    "Page_MeasureText"
    "Page_CurrentTextPos2"
    "Page_TextRect"
    "Doc_Image_Raw_LoadFromMemory"
    "Doc_Image_Png_LoadFromMemory"
    "Doc_Image_Jpeg_LoadFromMemory"
    "Doc_Image_Raw1Bit_LoadFromMemory"
    "Doc_TTFont_LoadFromMemory"))

(defparameter +janet-types+
  ;; Тип в gen | тип в распаковке | тип в упаковке
  '(:STATUS        ("uinteger"   . "integer")
    :CID           ("uinteger16" . "integer")
    :UNICODE       ("uinteger16" . "integer")
    :BYTE          ("uinteger8"  . "integer")
    :UINT          ("uinteger"   . "integer")
    :INT8          ("integer8"   . "integer")
    :INT           ("integer"    . "integer")
    :UINT8         ("uinteger8"  . "integer")
    :INT16         ("integer16"  . "integer")
    :UINT16        ("uinteger16" . "integer")
    :INT32         ("integer"    . "integer")
    :UINT32        ("uinteger"   . "integer")
    :FLOAT         ("float"      .  "number")
    :REAL          ("float"      .  "number")
    :DOUBLE        ("number"     .  "number")
    :BOOL          ("integer"    . "integer")
    :PAGESIZES     ("integer"    . "integer")
    :RAW_POINTER   ("pointer"    . "pointer")
    :DASH_PATTERN  ("pointer"    . "pointer")
    :ERROR_HANDLER ("pointer"    . "pointer")
    :ALLOC_FUNC    ("pointer"    . "pointer")
    :FREE_FUNC     ("pointer"    . "pointer")))


;; Генератор привязки Janet
(defun do-create-binding (args)
  (let* (;; Путь до файлов данных генератора
         (gen-dir (first args))

         ;; Папка для сохранения сгенерированных файлов
         (target (second args))

         ;; Список файлов данных генератора
         (data (directory
                (merge-pathnames (pathname gen-dir)
                                 (pathname "*.lsp"))))

         ;; Целевой файл
         (target-path (merge-pathnames (pathname target)
				       (pathname "binding.c"))))

    (let (;; Таблицы, заполняемые с помощью load-data
          (*enums-lsp*     (make-hash-table :test 'equalp))
          (*functions-lsp* (make-hash-table :test 'equalp))
          (*pointers-lsp*  (make-hash-table :test 'equalp))
          (*consts-lsp*    (make-hash-table :test 'equalp))
          (*defs-lsp*      (make-hash-table :test 'equalp))
          (*sizes-lsp*     nil)
          ;; Список, формируемый из экспортов
          ;; сущностей. Основа для формирования package.lisp
          (exports         nil))

      (dolist (data-file data)
        ;; Заполняем хеш-таблицы
        (load-data data-file))

      (dolist (sf +skip-functions+)
	(remhash sf *functions-lsp*))

      (let ((function-list "")
	    (janet-functions "")
	    (janet-enums "")
	    (page-sizes ""))

	(setf

	 page-sizes
	 (with-output-to-string (output)
	   (flet ((wr (fmt &rest values)
		    (apply #'format (cons output (cons fmt values)))))

	     (let ((page-size-header ""))
	       (wr "  // page_sizes.lsp~%")
	       (dolist (s *sizes-lsp*)
		 (let* ((skip    (getf s :skip))
			(id      (getf s :id))
			(caption (getf s :caption))
			(origin  (getf s :origin))
			(w       (getf s :width))
			(h       (getf s :height))
			(comment (format nil "~A ~A (~Amm x ~Amm)" origin caption w h))
			(skip-mark (if skip "// skip: " ""))
			(under (str:downcase (under (str:concat "page-size-" (under id))))))

		   (when (not (string-equal origin page-size-header))
		     (wr "  // ~A~%" origin)
		     (setf page-size-header origin))
		   (wr "  ~Ajanet_def(env, \"~A\", janet_wrap_integer(BRST_PAGE_SIZE_~A), \"~A\");~%" skip-mark under id comment))))))

	 janet-enums
	 (with-output-to-string (output)
	   (flet ((wr (fmt &rest values)
		    (apply #'format (cons output (cons fmt values)))))
	     (wr "  janet_def(env, \"mm\", janet_wrap_number(BRST_MM), \"Size in millimeters\");~%")
	     (wr "  janet_def(env, \"in\", janet_wrap_number(BRST_IN), \"Size in inches\");~%")
	     (wr "  janet_def(env, \"pi\", janet_wrap_number(BRST_PI), \"π value\");~%")

	     (let ((enum-header ""))
       	       (dolist (e (sort
			   (alexandria:hash-table-alist *enums-lsp*)
			   #'string-lessp :key #'cadr))

		 (let* ((enum (car e))
			(filename (cadr e))
			(data (cddr e))
			(elements (getf data :elements)))

		   (when (not (string-equal filename enum-header))
		     (wr "  // ~A~%" filename)
		     (setf enum-header filename))

		   (dolist (em elements)
		     (let ((under (str:downcase (under (getf em :element))))
			   (em-name (getf em :element))
			   (en (str:replace-all
				"\"" "\\\""
				(str:replace-all
				 "`" "'"
				 (str:replace-all "\\" "\\\\"
						  (str:replace-all "
"
								   "\\n" (or (getf em :en) "")))))))
		       (wr "  janet_def(env, \"~A\", janet_wrap_integer(BRST_~A), \"~A\");~%" under em-name en))))))))

	 function-list
	 (with-output-to-string (output)
	   (setf
	    janet-functions
	    (with-output-to-string (jns)
	      ;; Функция печати
	      (flet ((wr (fmt &rest values)
		       (apply #'format (cons output (cons fmt values))))
		     (jr (fmt &rest values)
		       (apply #'format (cons jns (cons fmt values)))))
		;; Эта переменная нужна для того, чтобы отслеживать смену файла
		(let ((function-header ""))
		  ;; Сортируем функции по файлу и перебираем функции
		  (dolist (f (sort
			      (alexandria:hash-table-alist *functions-lsp*)
			      #'string-lessp :key #'cadr))
		    ;; Для отдельной функции получаем имя, файл, параметры и тип
		    (let* ((function (car f))
			   (filename (cadr f))
			   (data (cddr f))
			   (params (getf data :params))
			   (result (getf data :result))
			   (en (str:replace-all
				"\"" "\\\""
				(str:replace-all
				 "`" "'"
				 (str:replace-all "\\" "\\\\"
						  (str:replace-all "
"
								   "\\n" (or (getf data :en) ""))))))
			   (return-type (getf result :type))
			   (under (str:downcase (under function)))
			   (param-names (if (zerop (length params))
					    ""
					    (str:join ", " (mapcar #'(lambda (x) (getf x :name)) params))))
			   (param-names1 (if (zerop (length params))
					     ""
					     (str:concat " " (str:join " " (mapcar #'(lambda (x) (getf x :name)) params))))))

		      ;; Смена имени файла
		      (when (not (string-equal filename function-header))
			(wr "// ~A~%" filename)
			(jr "  // ~A~%" filename)
			(setf function-header filename))

		      (jr "  {\"~A\", br_~A, \"(brst/~A~A)\\n\\n~A\"},~%" under function under param-names1 en)

		      ;; Шапка функции
		      (wr "static Janet br_~A(int32_t argc, Janet *argv) {~%" function)

		      ;; Проверка арности
		      (if (zerop (length params))
			  (wr "  (void) argv; janet_fixarity(argc, 0);~%")
			  (wr "  janet_fixarity(argc, ~A);~%" (length params)))

		      ;; Расстановка параметров
		      (let ((i 0))
			(dolist (p params)
			  (let ((name (getf p :name))
				(type (getf p :type)))
			    ;; Получаем getter'ы для типов параметров
			    (let* ((type-cons (getf +janet-types+ (intern (string-upcase type) 'keyword)))
				   (def  (gethash type *defs-lsp*))
				   (ptr  (gethash type *pointers-lsp*))
				   (enum (gethash type *enums-lsp*))
				   (param-type (if type-cons
						   (car type-cons)
						   ;; Подменяем перечисления на integer,
						   ;; указатели и определения на pointer
						   (cond
						     (def "pointer")
						     (ptr "pointer")
						     (enum "integer")
						     (t type)))))
			      (if (string= "CSTR" type)
				  (wr "  BRST_CSTR ~A = (BRST_CSTR)janet_getstring(argv, ~D);~%" name i)
				  (wr "  BRST_~A ~A = (BRST_~A)janet_get~A(argv, ~D);~%"
				      type
				      name
				      type
				      param-type
				      i)))
			    (incf i))))

		      ;; Подготовка результата
		      (let* ((type-cons (getf +janet-types+ (intern (string-upcase return-type) 'keyword)))
			     (def       (gethash return-type *defs-lsp*))
			     (ptr       (gethash return-type *pointers-lsp*))
			     (enum      (gethash return-type *enums-lsp*))
			     (ret-type  (if type-cons
					    (cdr type-cons)
					    ;; Подменяем перечисления на integer,
					    ;; указатели и определения на pointer
					    (cond
					      (def "pointer")
					      (ptr "pointer")
					      (enum "integer")
					      (t return-type)))))
			(if (string= return-type "void")
			    (progn
			      (wr "  BRST_~A(~A);~%" function param-names)
			      (wr "  return janet_wrap_nil();~%"))
			    (if (string= "CSTR" return-type)
				(progn
				  (wr "  BRST_CSTR ret = BRST_~A(~A);~%" function param-names)
				  (wr "  return janet_cstringv(ret);~%"))
				(progn
				  (wr "  BRST_~A ret = BRST_~A(~A);~%" return-type function param-names)
				  (wr "  return janet_wrap_~A(ret);~%" ret-type)))))

		      (wr "}~%~%")))))))))

	(alexandria:write-string-into-file
	 (with-output-to-string (res)
	   (flet ((wr (fmt &rest values)
		    (apply #'format (cons res (cons fmt values)))))
	     (wr "#include <janet.h>~%")
	     (wr "#include <brst.h>~%~%")

	     (princ function-list res)

	     (wr "static const JanetReg cfuns[] = {~%")
	     (princ janet-functions res)
	     (wr "~%  {NULL, NULL, NULL}~%")
	     (wr "};~%")
	     (wr "~%JANET_MODULE_ENTRY(JanetTable *env) {~%")
	     (princ janet-enums res)
	     (princ page-sizes res)
	     (wr "~%  janet_cfuns(env, \"brst\", cfuns);~%")
	     (wr "}")))
	 target-path
	 :if-exists :supersede
	 :if-does-not-exist :create)
	))))
