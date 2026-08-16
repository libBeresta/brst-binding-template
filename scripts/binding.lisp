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
  '("Page_MeasureText"
    "Page_CurrentTextPos2"
    "Page_TextRect"
    "Doc_Image_Raw_LoadFromMemory"
    "Doc_Image_Png_LoadFromMemory"
    "Doc_Image_Jpeg_LoadFromMemory"
    "Doc_Image_Raw1Bit_LoadFromMemory"
    "Doc_TTFont_LoadFromMemory"))

(defparameter +janet-types+
  ;; Тип в gen | тип в распаковке | тип в упаковке
  '(:STATUS        ("uinteger"   .  "number")
    :CID           ("uinteger16" .  "number")
    :UNICODE       ("uinteger16" .  "number")
    :BYTE          ("uinteger8"  .  "number")
    :INT8          ("integer8"   . "integer")
    :UINT8         ("uinteger8"  . "integer")
    :INT16         ("integer16"  . "integer")
    :UINT16        ("uinteger16" . "integer")
    :INT32         ("integer"    . "integer")
    :UINT32        ("uinteger"   . "integer")
    :FLOAT         ("float"      .  "number")
    :REAL          ("float"      .  "number")
    :DOUBLE        ("number"     .  "number")
    :BOOL          ("integer"    . "integer")
    :RAW-POINTER   ("pointer"    . "pointer")
    :DASH-PATTERN  ("pointer"    . "pointer")
    :ERROR-HANDLER ("pointer"    . "pointer")    
    :ALLOC-FUNC    ("pointer"    . "pointer")    
    :FREE-FUNC     ("pointer"    . "pointer")))


;; Генератор привязки Janet
(defun do-create-binding (args)
  (let* (;; Путь до файлов данных генератора
         (gen-dir (first args))

         ;; Путь до файлов-шаблонов
         (templates-dir (second args))

         ;; Папка для сохранения сгенерированных файлов
         (target (third args))

         ;; Список файлов данных генератора
         (data (directory
                (merge-pathnames (pathname gen-dir)
                                 (pathname "*.lsp"))))

         ;; Список файлов-шаблонов
         (ecl-template  (merge-pathnames (pathname templates-dir)
                                         (pathname "janet.dj")))
         ;; Целевая папка
         (target-path (pathname target)))

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
      
      (let ((function-list ""))
	(setf function-list 
	      (with-output-to-string (output)
		;; Функция печати
		(flet ((wr (fmt &rest values)
			 (apply #'format (cons output (cons fmt values)))))
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
			     (return-type (getf result :type))
			     (param-names (if (zerop (length params))
					      ""
					      (str:join ", " (mapcar #'(lambda (x) (getf x :name)) params)))))

			;; Смена имени файла
			(when (not (string-equal filename function-header))
			  (wr "// ~A~%" filename)
			  (setf function-header filename))

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
			      ;; Получаем getter'ы для 
			      (let ((type-cons (getf +janet-types+ (intern (string-upcase type) 'keyword)))
				    (def  (gethash type *defs-lsp*))
				    (ptr  (gethash type *pointers-lsp*))
				    (enum (gethash type *enums-lsp*)))
				(wr "  ~A ~A = (~A)janet_get_~A(argv, ~D);~%"
				    type
				    name
				    type
				    (if type-cons
					(car type-cons)
					;; Подменяем перечисления на integer,
					;; указатели и определения на pointer
					(cond
					  (def "pointer")
					  (ptr "pointer")
					  (enum "integer")
					  (t type)))
				    i))
			      (incf i))))
			
			;; Подготовка результата
			(if (string= return-type "void")
			    (wr "  return janet_wrap_nil();~%")
			    (progn
			      (wr "  ~A ret = BRST_~A(~A);~%" return-type function param-names)
			      (wr "  return janet_wrap_~A(ret);~%" return-type)))
			
			(wr "}~%~%")

			))))))
	(print function-list)
	(print (alexandria:hash-table-keys *enums-lsp*))
	(print (alexandria:hash-table-keys *pointers-lsp*))
	(print (alexandria:hash-table-keys *defs-lsp*))
	))))
