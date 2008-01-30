;;;; -*- Lisp -*-

#|
To autoload mcclim-freetype after mcclim, link this file to a
directory in your asdf:*central-registry* and add the following to
your lisp's init file:

 (defmethod asdf:perform :after ((o asdf:load-op) (s (eql (asdf:find-system :clim-clx))))
   (asdf:oos 'asdf:load-op :mcclim-freetype))
|#

(defpackage :mcclim-freetype-system (:use :cl :asdf))
(in-package :mcclim-freetype-system)

(defclass uncompiled-cl-source-file (source-file) ())

(defmethod perform ((o compile-op) (f uncompiled-cl-source-file))
  t)
(defmethod perform ((o load-op) (f uncompiled-cl-source-file))
  (mapcar #'load (input-files o f)))
(defmethod output-files ((operation compile-op) (c uncompiled-cl-source-file))
  nil)
(defmethod input-files ((operation load-op) (c uncompiled-cl-source-file))
  (list (component-pathname c)))
(defmethod operation-done-p ((operation compile-op) (c uncompiled-cl-source-file))
  t)
(defmethod source-file-type ((c uncompiled-cl-source-file) (s module))
  "lisp")

(defsystem :mcclim-freetype
  :depends-on (:clim-clx :mcclim #-sbcl :cffi)
  :serial t
  :components
  #+sbcl
  ((:file "freetype-package")
   (:uncompiled-cl-source-file "freetype-ffi")
   (:file "freetype-fonts")
   (:file "fontconfig"))
  #-sbcl
  ((:file "freetype-package-cffi")
   (:uncompiled-cl-source-file "freetype-cffi")
   (:file "freetype-fonts-cffi")))


#+sbcl
(defmethod perform :after ((o load-op) (s (eql (asdf:find-system :mcclim-freetype))))
  "Detect fonts using fc-match"
  (funcall (find-symbol (symbol-name '#:autoconfigure-fonts) :mcclim-freetype)))


;;; Freetype autodetection
#-sbcl
(progn
  (defun parse-fontconfig-output (s)
    (let* ((match-string (concatenate 'string (string #\Tab) "file:"))
	   (matching-line
	    (loop for l = (read-line s nil nil)
	       while l
	       if (= (mismatch l match-string) (length match-string))
	       do (return l)))
	   (filename (when matching-line
		       (probe-file
			(subseq matching-line
				(1+ (position #\" matching-line :from-end nil :test #'char=))
				(position #\" matching-line :from-end t   :test #'char=))))))
      (when filename
	(make-pathname :directory (pathname-directory filename)))))

  (defun warn-about-unset-font-path ()
    (warn "~%~%NOTE:~%~
* Remember to set mcclim-freetype:*freetype-font-path* to the
  location of the Bitstream Vera family of fonts on disk. If you
  don't have them, get them from http://www.gnome.org/fonts/~%~%~%"))

  (defmethod perform :after ((o load-op) (s (eql (asdf:find-system :mcclim-freetype))))
    (unless
	(setf (symbol-value (intern "*FREETYPE-FONT-PATH*" :mcclim-freetype))
	      (find-bitstream-fonts))
      (warn-about-unset-font-path)))

  (defun find-bitstream-fonts ()
    (with-input-from-string
	(s (with-output-to-string (asdf::*verbose-out*)
	     (let ((code (asdf:run-shell-command "fc-match -v Bitstream Vera")))
	       (unless (zerop code)
		 (warn "~&fc-match failed with code ~D.~%" code)))))
      (parse-fontconfig-output s))))
