(import brst/brst :export true :prefix "")

(defmacro with-pdf-document
  [pdf filename & body]
  ~(let [,pdf (brst/doc-new-empty)]
      (defer (brst/doc-free ,pdf)
      ,;body
      (brst/doc-savetofile ,pdf ,filename))))
