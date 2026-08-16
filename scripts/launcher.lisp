(multiple-value-bind (args found--)
    (rem-args (ext:command-args) (ext:command-args))

  (if found--
      (if (< (length args) 3)
          (princ "There must be parameters:
  <generator data folder> <templates folder> <target folder>
  set after '--'.
")
          (progn
            (do-create-binding args)
            (si:exit 0)))
      (princ "Please call with '--' command line argument.
"))
  (si:exit 1))
