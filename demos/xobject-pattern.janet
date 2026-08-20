(use brst)

(with-pdf-document pdf "xobject_pattern.pdf"
  (let [page (doc-page-add pdf)]
    (page-setsize page
                  page-size-a4
                  page-orientation-landscape)

    (let [xobj (doc-xobject-new pdf
                                100 100
                                1 1)
          stream (xobject-stream xobj)
          matrix (doc-matrix-scale pdf
                                   (doc-matrix-identity pdf)
                                   0.5
                                   0.5)
          pattern (doc-pattern-tiling-new pdf
                                          0 0
                                          10 10
                                          10 10
                                          matrix)
          pattern-stream (doc-pattern-stream pattern)]
      (stream-setlinewidth pattern-stream 0.49814)

      (stream-moveto pattern-stream -1  4)
      (stream-lineto pattern-stream  6 11)
      (stream-moveto pattern-stream  4 -1)
      (stream-lineto pattern-stream 11  6)
      (stream-stroke pattern-stream)

      (doc-dict-rgbpatternfill-select pdf xobj 1 0 0 pattern)
      (stream-rectangle stream 20 20 80 80)
      (stream-fill stream)
      
      (page-translate page 50 50)
      (page-xobject-execute page xobj)

      (let [page (doc-page-add pdf)]
        (page-setsize page
                      page-size-a4
                      page-orientation-landscape)
        (page-translate page 200 110)
        (page-xobject-execute page xobj)))))
