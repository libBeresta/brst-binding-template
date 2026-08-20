(import brst/brst :export true :prefix "")

(defmacro with-pdf-document
  [pdf filename & body]
  ~(let [,pdf (doc-new-empty)]
      (defer (doc-free ,pdf)
      ,;body
      (doc-savetofile ,pdf ,filename))))

(defmacro with-ttf-font
  [font-var pdf-var filename & body]
  (when (os/stat ~,filename)
    (let [f-name (gensym)
 	      font-name (gensym)]
      ~(let [,f-name ,filename
             ,font-name (doc-ttfont-loadfromfile ,pdf-var ,f-name 1)
	         ,font-var  (doc-font ,pdf-var ,font-name "UTF-8")]
	   ,;body))))
