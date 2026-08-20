(use brst)

(with-pdf-document pdf "properties.pdf"
  (let [page (doc-page-add pdf)]
    (page-setsize page
                  page-size-a4
                  page-orientation-landscape)

    (doc-useutfencodings pdf)
    (doc-encoder-setcurrent pdf "UTF-8")

    (doc-setinfoattr pdf info-author   "Автор / Author / Autor")
    (doc-setinfoattr pdf info-creator  "Разработчик / Creator / Creador")
    (doc-setinfoattr pdf info-producer "Продюсер / Producer / Productor")
    (doc-setinfoattr pdf info-title    "Заголовок / Title / Título")
    (doc-setinfoattr pdf info-subject  "Тема / Subject / Asunto")
    (doc-setinfoattr pdf info-keywords "Ключевые слова, Keywords, Palabras clave")

    (let [date (doc-date-now pdf)]
      (doc-setinfodateattr pdf info-creation-date date)
      (doc-setinfodateattr pdf info-mod-date date))))
