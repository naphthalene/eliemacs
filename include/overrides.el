;;; override.el --- Various overrides.
;;-----------------------------------------------------------------------------
;; Written by Eli Barzilay: Maze is Life!   (eli@barzilay.org)

;;-----------------------------------------------------------------------------
;; Override from "simple.el": avoid the "helpful" octal/hexadecimal if it goes
;; into the buffer

(defun eval-expression-print-format (value)
  "Format VALUE as a result of evaluated expression.
Return a formatted string which is displayed in the echo area
in addition to the value printed by prin1 in functions which
display the result of expression evaluation."
  (if (and (integerp value)
           (not (bufferp standard-output)) ;ELI
           (or (not (memq this-command '(eval-last-sexp eval-print-last-sexp)))
               (eq this-command last-command)
               (if (boundp 'edebug-active) edebug-active)))
      (let ((char-string
             (if (or (if (boundp 'edebug-active) edebug-active)
		     (memq this-command '(eval-last-sexp eval-print-last-sexp)))
                 (prin1-char value))))
        (if char-string
            (format " (#o%o, #x%x, %s)" value value char-string)
          (format " (#o%o, #x%x)" value value)))))

;;-----------------------------------------------------------------------------
;; Overrides from "help.el", and showing temporary buffers
;; (Works better than ehelp.)

;; Don't show a message, only set return-method.
(defun help-print-return-message (&optional function)
  "Display or return message saying how to restore windows after help command.
This function assumes that `standard-output' is the help buffer.
It computes a message, and applies the optional argument FUNCTION to it.
If FUNCTION is nil, it applies `message', thus displaying the message.
In addition, this function sets up `help-return-method', which see, that
specifies what to do when the user exits the help buffer."
  (and (not (get-buffer-window standard-output))
       (let ((first-message
	      (cond ((or
		      pop-up-frames
		      (special-display-p (buffer-name standard-output)))
		     (setq help-return-method (cons (selected-window) t))
		     ;; If the help output buffer is a special display buffer,
		     ;; don't say anything about how to get rid of it.
		     ;; First of all, the user will do that with the window
		     ;; manager, not with Emacs.
		     ;; Secondly, the buffer has not been displayed yet,
		     ;; so we don't know whether its frame will be selected.
		     nil)
		    (display-buffer-reuse-frames
		     (setq help-return-method (cons (selected-window)
						    'quit-window))
		     nil)
		    ((not (one-window-p t))
		     (setq help-return-method
			   (cons (selected-window) 'quit-window))
		     "Type \\[display-buffer] RET to restore the other window.")
		    (pop-up-windows
		     (setq help-return-method (cons (selected-window) t))
		     "Type \\[delete-other-windows] to remove help window.")
		    (t
		     (setq help-return-method
			   (list (selected-window) (window-buffer)
				 (window-start) (window-point)))
		     "Type \\[switch-to-buffer] RET to remove help window."))))
	 (funcall (or function 'identity) ;ELI
		  (concat
		   (if first-message
		       (substitute-command-keys first-message))
		   (if first-message "  ")
		   ;; If the help buffer will go in a separate frame,
		   ;; it's no use mentioning a command to scroll, so don't.
		   (if (or pop-up-windows
			   (special-display-p (buffer-name standard-output)))
		       nil
		     (if (same-window-p (buffer-name standard-output))
			 ;; Say how to scroll this window.
			 (substitute-command-keys
			  "\\[scroll-up] to scroll the help.")
		       ;; Say how to scroll some other window.
		       (substitute-command-keys
			"\\[scroll-other-window] to scroll the help."))))))))

(defvar eli-popup-exit-conf nil
  "Window configuration to restore after quitting viewing a temp buffer.")
(make-variable-buffer-local 'eli-popup-exit-conf)

(defun buffer-op-and-restore-winconf (buf op)
  (let ((conf (buffer-local-value 'eli-popup-exit-conf buf)))
    (unless (window-minibuffer-p (selected-window)) (funcall op buf))
    (when (and conf (eq (selected-frame) (window-configuration-frame conf)))
      (set-window-configuration conf))))

;; Kill help windows when done
(add-hook 'help-mode-hook
  (lambda ()
    (setq view-exit-action
          (lambda (buf) (buffer-op-and-restore-winconf buf 'kill-buffer)))))
;; Other possible options:
;; (add-hook 'help-mode-hook (lambda () (setq view-exit-action 'kill-buffer)))
;; (setq-default view-exit-action 'bury-buffer) ; always!

;; Bury apropos windows
(add-hook 'apropos-mode-hook
  (lambda ()
    (setq view-exit-action
          (lambda (buf) (buffer-op-and-restore-winconf buf 'bury-buffer)))))

;; Use my own hook that avoids a bug in 22.1
;; otherwise I could use `(temp-buffer-resize-mode 1)'
;; --> actually it looks like it works, leave the code below in case I
;;     find a bug, still
(temp-buffer-resize-mode 1)
;; (defun eli-resize-temp-buffer-window ()
;;   "Fixed version of `resize-temp-buffer-window'."
;;   (unless (or (one-window-p 'nomini)
;;               (not (pos-visible-in-window-p (point-min)))
;;               ;; (/=  (frame-width) (window-width))
;;               )
;;     (fit-window-to-buffer
;;      (selected-window)
;;      (if (functionp temp-buffer-max-height)
;;        (funcall temp-buffer-max-height (current-buffer))
;;        temp-buffer-max-height))))
;; (add-hook 'temp-buffer-show-hook 'eli-resize-temp-buffer-window 'append)

;; Stay in temp buffers (for navigation)
(defun eli-temp-buffer-show-function (buf)
  ;; A rough Lisp version of the code in temp_output_buffer_show, which leaves
  ;; us in the new window unless it is a completions window
  (let* ((origbuf (current-buffer))
         (origwin (get-buffer-window origbuf))
         (temp-buffer-show-function nil)
         (conf (current-window-configuration))
         (win (display-buffer buf)))
    (unless (eq (selected-frame) (window-frame win))
      (make-frame-visible (window-frame win)))
    (setq minibuffer-scroll-window win)
    (set-window-start win 0)
    (set-window-hscroll win 0)
    (unless (equal (buffer-name buf) "*Completions*")
      (select-window win)
      (set-buffer buf)
      ;; save the window configuration here, while we can (but not if there is
      ;; one already, eg -- with help links)
      (unless (and (eq buf origbuf) (eq win origwin))
        (setq eli-popup-exit-conf conf))
      (run-hooks 'temp-buffer-show-hook)
      (select-window win)
      (view-mode 1))))
(setq temp-buffer-show-function 'eli-temp-buffer-show-function)

(defun eli-popup-view (buf &optional exit-action)
  "Show BUF in a window, make it in `view-mode'."
  (let* ((special-display-buffer-names nil) ; no looping
         (win (get-buffer-window buf)))
    (unless win
      (eli-temp-buffer-show-function buf)
      (setq win (get-buffer-window buf)))
    (select-window win)
    (set-buffer buf)
    (view-mode 1)
    (setq view-exit-action
          (lambda (buf) (buffer-op-and-restore-winconf buf 'bury-buffer)))))

;; Use this for popping shell results.
(setq special-display-buffer-names
      (cons '("*Shell Command Output*" eli-popup-view)
            special-display-buffer-names))

;;-----------------------------------------------------------------------------
;; Override from "userlock.el": make a changed file automatically reload

(when eli-auto-revert-on-change

(defvar inside-ask-user-about-supersession-threat nil)

;; do it after loading, so the new definition isn't replaced by the original
(eval-after-load "userlock" '(progn

(defun ask-user-about-supersession-threat (fn)
  "(DON'T) Ask a user who is about to modify an obsolete buffer what to do.
This function has two choices: it can return, in which case the modification
of the buffer will proceed, or it can (signal 'file-supersession (file)),
in which case the proposed buffer modification will not be made.

You can rewrite this to use any criterion you like to choose which one to do.
The buffer in question is current when this function is called.

THIS IS A MODIFIED VERSION THAT AUTOMATICALLY RELOADS THE FILE."
  (unless inside-ask-user-about-supersession-threat
    (let ((inside-ask-user-about-supersession-threat t)
          (opoint (point))
          (strt   (window-start (get-buffer-window (current-buffer))))
          (inhibit-read-only t))
      (discard-input)
      ;; hack: make the previous version available with undo
      (undo-boundary) (erase-buffer)
      (let ((saved-undo buffer-undo-list))
        (setq buffer-undo-list nil)
        (revert-buffer t t t)
        (setq buffer-undo-list
              (cons (cons (point-min) (point-max)) saved-undo)))
      (set-window-start (get-buffer-window (current-buffer)) strt)
      (goto-char opoint)
      (error "%s was modifed on disk, reloaded" (file-name-nondirectory fn)))))

))

)

;;-----------------------------------------------------------------------------
;; Override from "files.el": don't ask about reverting a buffer, just say it

(when eli-auto-revert-on-change

;; do it after loading, so the new definition isn't replaced by the original
(eval-after-load "files" '(progn

(defun find-file-noselect (filename &optional nowarn rawfile wildcards)
  "Read file FILENAME into a buffer and return the buffer.
If a buffer exists visiting FILENAME, return that one, but
verify that the file has not changed since visited or saved.
The buffer is not selected, just returned to the caller.
Optional second arg NOWARN non-nil means suppress any warning messages.
Optional third arg RAWFILE non-nil means the file is read literally.
Optional fourth arg WILDCARDS non-nil means do wildcard processing
and visit all the matching files.  When wildcards are actually
used and expanded, return a list of buffers that are visiting
the various files."
  (setq filename
	(abbreviate-file-name
	 (expand-file-name filename)))
  (if (file-directory-p filename)
      (or (and find-file-run-dired
	       (run-hook-with-args-until-success
		'find-directory-functions
		(if find-file-visit-truename
		    (abbreviate-file-name (file-truename filename))
		  filename)))
	  (error "%s is a directory" filename))
    (if (and wildcards
	     find-file-wildcards
	     (not (string-match "\\`/:" filename))
	     (string-match "[[*?]" filename))
	(let ((files (condition-case nil
			 (file-expand-wildcards filename t)
		       (error (list filename))))
	      (find-file-wildcards nil))
	  (if (null files)
	      (find-file-noselect filename)
	    (mapcar #'find-file-noselect files)))
      (let* ((buf (get-file-buffer filename))
	     (truename (abbreviate-file-name (file-truename filename)))
	     (attributes (file-attributes truename))
	     (number (nthcdr 10 attributes))
	     ;; Find any buffer for a file which has same truename.
	     (other (and (not buf) (find-buffer-visiting filename))))
	;; Let user know if there is a buffer with the same truename.
	(if other
	    (progn
	      (or nowarn
		  find-file-suppress-same-file-warnings
		  (string-equal filename (buffer-file-name other))
		  (message "%s and %s are the same file"
			   filename (buffer-file-name other)))
	      ;; Optionally also find that buffer.
	      (if (or find-file-existing-other-name find-file-visit-truename)
		  (setq buf other))))
	;; Check to see if the file looks uncommonly large.
	(when (not (or buf nowarn))
	  (abort-if-file-too-large (nth 7 attributes) "open" filename))
	(if buf
	    ;; We are using an existing buffer.
	    (let (nonexistent)
	      (or nowarn
		  (verify-visited-file-modtime buf)
		  (cond ((not (file-exists-p filename))
			 (setq nonexistent t)
			 (message "File %s no longer exists!" filename))
			;; Certain files should be reverted automatically
			;; if they have changed on disk and not in the buffer.
			((and (not (buffer-modified-p buf))
			      (let ((tail revert-without-query)
				    (found nil))
				(while tail
				  (if (string-match (car tail) filename)
				      (setq found t))
				  (setq tail (cdr tail)))
				found))
			 (with-current-buffer buf
			   (message "Reverting file %s..." filename)
			   (revert-buffer t t)
			   (message "Reverting file %s...done" filename)))
                        ;;ELI:
                        (t
                         (message "File %s changed on disk!%s"
                                  (file-name-nondirectory filename)
                                  (if (buffer-modified-p buf)
                                    " (note: local modifications)"
                                    " (touch to revert)"))
                         (ding t))
			((yes-or-no-p
			  (if (string= (file-name-nondirectory filename)
				       (buffer-name buf))
			      (format
			       (if (buffer-modified-p buf)
				   "File %s changed on disk.  Discard your edits? "
				 "File %s changed on disk.  Reread from disk? ")
			       (file-name-nondirectory filename))
			    (format
			     (if (buffer-modified-p buf)
				 "File %s changed on disk.  Discard your edits in %s? "
			       "File %s changed on disk.  Reread from disk into %s? ")
			     (file-name-nondirectory filename)
			     (buffer-name buf))))
			 (with-current-buffer buf
			   (revert-buffer t t)))))
	      (with-current-buffer buf

		;; Check if a formerly read-only file has become
		;; writable and vice versa, but if the buffer agrees
		;; with the new state of the file, that is ok too.
		(let ((read-only (not (file-writable-p buffer-file-name))))
		  (unless (or nonexistent
			      (eq read-only buffer-file-read-only)
			      (eq read-only buffer-read-only))
		    (when (or nowarn
			      (let ((question
				     (format "File %s is %s on disk.  Change buffer mode? "
					     buffer-file-name
					     (if read-only "read-only" "writable"))))
				(y-or-n-p question)))
		      (setq buffer-read-only read-only)))
		  (setq buffer-file-read-only read-only))

		(when (and (not (eq (not (null rawfile))
				    (not (null find-file-literally))))
			   (not nonexistent)
			   ;; It is confusing to ask whether to visit
			   ;; non-literally if they have the file in
			   ;; hexl-mode or image-mode.
			   (not (memq major-mode '(hexl-mode image-mode))))
		  (if (buffer-modified-p)
		      (if (y-or-n-p
			   (format
			    (if rawfile
				"The file %s is already visited normally,
and you have edited the buffer.  Now you have asked to visit it literally,
meaning no coding system handling, format conversion, or local variables.
Emacs can only visit a file in one way at a time.

Do you want to save the file, and visit it literally instead? "
				"The file %s is already visited literally,
meaning no coding system handling, format conversion, or local variables.
You have edited the buffer.  Now you have asked to visit the file normally,
but Emacs can only visit a file in one way at a time.

Do you want to save the file, and visit it normally instead? ")
			    (file-name-nondirectory filename)))
			  (progn
			    (save-buffer)
			    (find-file-noselect-1 buf filename nowarn
						  rawfile truename number))
			(if (y-or-n-p
			     (format
			      (if rawfile
				  "\
Do you want to discard your changes, and visit the file literally now? "
				"\
Do you want to discard your changes, and visit the file normally now? ")))
			    (find-file-noselect-1 buf filename nowarn
						  rawfile truename number)
			  (error (if rawfile "File already visited non-literally"
				   "File already visited literally"))))
		    (if (y-or-n-p
			 (format
			  (if rawfile
			      "The file %s is already visited normally.
You have asked to visit it literally,
meaning no coding system decoding, format conversion, or local variables.
But Emacs can only visit a file in one way at a time.

Do you want to revisit the file literally now? "
			    "The file %s is already visited literally,
meaning no coding system decoding, format conversion, or local variables.
You have asked to visit it normally,
but Emacs can only visit a file in one way at a time.

Do you want to revisit the file normally now? ")
			  (file-name-nondirectory filename)))
			(find-file-noselect-1 buf filename nowarn
					      rawfile truename number)
		      (error (if rawfile "File already visited non-literally"
			       "File already visited literally"))))))
	      ;; Return the buffer we are using.
	      buf)
	  ;; Create a new buffer.
	  (setq buf (create-file-buffer filename))
	  ;; find-file-noselect-1 may use a different buffer.
	  (find-file-noselect-1 buf filename nowarn
				rawfile truename number))))))

;;ELI: this is unchanged, but copied since before 23.2 it had only two
;;     inputs, so copy it here and make it optional
(defun abort-if-file-too-large (size op-type &optional filename)
  "If file SIZE larger than `large-file-warning-threshold', allow user to abort.
OP-TYPE specifies the file operation being performed (for message to user)."
  (when (and large-file-warning-threshold size
	     (> size large-file-warning-threshold)
	     (not (y-or-n-p (format "File %s is large (%dMB), really %s? "
				    (file-name-nondirectory filename)
				    (/ size 1048576) op-type))))
    (error "Aborted")))

)))

;;-----------------------------------------------------------------------------
;; Override from "files.el": make this respect case-folding

(defun file-expand-wildcards (pattern &optional full)
  "Expand wildcard pattern PATTERN.
This returns a list of file names which match the pattern.

If PATTERN is written as an absolute file name,
the values are absolute also.

If PATTERN is written as a relative file name, it is interpreted
relative to the current default directory, `default-directory'.
The file names returned are normally also relative to the current
default directory.  However, if FULL is non-nil, they are absolute."
  (save-match-data
    (let* ((nondir (file-name-nondirectory pattern))
	   (dirpart (file-name-directory pattern))
	   ;; A list of all dirs that DIRPART specifies.
	   ;; This can be more than one dir
	   ;; if DIRPART contains wildcards.
	   (dirs (if (and dirpart
			  (string-match "[[*?]"
					(or (file-remote-p dirpart 'localname)
					    dirpart)))
		     (mapcar 'file-name-as-directory
			     (file-expand-wildcards (directory-file-name dirpart)))
		   (list dirpart)))
	   contents)
      (while dirs
	(when (or (null (car dirs))	; Possible if DIRPART is not wild.
		  (and (file-directory-p (directory-file-name (car dirs)))
		       (file-readable-p (car dirs))))
	  (let ((this-dir-contents
		 ;; Filter out "." and ".."
		 (delq nil
		       (mapcar #'(lambda (name)
				   (let ((n (file-name-nondirectory name)))
                                     (and (not (member n '("." "..")))
                                          ;; ELI: do the wildcard filtering
                                          ;; here, not in directory files which
                                          ;; doesn't respect case folding
                                          (string-match (wildcard-to-regexp nondir)
                                                        n)
                                          name)))
			       (directory-files (or (car dirs) ".") full
						(wildcard-to-regexp nondir))))))
	    (setq contents
		  (nconc
		   (if (and (car dirs) (not full))
		       (mapcar (function (lambda (name) (concat (car dirs) name)))
			       this-dir-contents)
		     this-dir-contents)
		   contents))))
	(setq dirs (cdr dirs)))
      contents)))

;;-----------------------------------------------------------------------------
;; Override from "comint.el": remove the completions window on *any* key
;; other than the one used to show the completions (tab, usually).

(eval-after-load "comint" '(progn

(defun comint-dynamic-list-completions (completions &optional common-substring)
  "Display a list of sorted COMPLETIONS.
The meaning of COMMON-SUBSTRING is the same as in `display-completion-list'.
Typing any key flushes the completions buffer."
  (let ((window (get-buffer-window "*Completions*" 0)))
    (setq completions (sort completions 'string-lessp))
    (if (and (eq last-command this-command)
	     window (window-live-p window) (window-buffer window)
	     (buffer-name (window-buffer window))
	     ;; The above tests are not sufficient to detect the case where we
	     ;; should scroll, because the top-level interactive command may
	     ;; not have displayed a completions window the last time it was
	     ;; invoked, and there may be such a window left over from a
	     ;; previous completion command with a different set of
	     ;; completions.  To detect that case, we also test that the set
	     ;; of displayed completions is in fact the same as the previously
	     ;; displayed set.
	     (equal completions
		    (buffer-local-value 'comint-displayed-dynamic-completions
					(window-buffer window))))
	;; If this command was repeated, and
	;; there's a fresh completion window with a live buffer,
	;; and this command is repeated, scroll that window.
	(with-current-buffer (window-buffer window)
	  (if (pos-visible-in-window-p (point-max) window)
	      (set-window-start window (point-min))
	    (save-selected-window
	      (select-window window)
	      (scroll-up))))

      ;; Display a completion list for the first time.
      (setq comint-dynamic-list-completions-config
	    (current-window-configuration))
      (with-output-to-temp-buffer "*Completions*"
	(display-completion-list completions common-substring))
      (if (window-minibuffer-p (selected-window))
	  (minibuffer-message "Type anything to flush; repeat completion command to scroll")
	(message "Type space to flush; repeat completion command to scroll")))

    ;; Read the next key, to process SPC.
    (let (key first)
      (if (with-current-buffer (get-buffer "*Completions*")
	    (set (make-local-variable 'comint-displayed-dynamic-completions)
		 completions)
	    (setq key (read-key-sequence nil)
		  first (aref key 0))
	    (and (consp first) (consp (event-start first))
		 (eq (window-buffer (posn-window (event-start first)))
		     (get-buffer "*Completions*"))
		 (eq (key-binding key) 'mouse-choose-completion)))
	  ;; If the user does mouse-choose-completion with the mouse,
	  ;; execute the command, then delete the completion window.
	  (progn
	    (choose-completion first)
	    (set-window-configuration comint-dynamic-list-completions-config))
        ;; ELI: replacing this code
	;; (if (eq first ?\s)
	;;     (set-window-configuration comint-dynamic-list-completions-config)
	;;   (setq unread-command-events (listify-key-sequence key)))
        (if (not (eq first ?\t))
          (set-window-configuration comint-dynamic-list-completions-config))
        (setq unread-command-events (listify-key-sequence key))))))

))

;;-----------------------------------------------------------------------------
;; Override from "minibuffer.el": leave cursor at the point where possible new
;; characters could be entered (eg, with "select-window", it should leave the
;; cursor between the "t-").

' ;; looks like this is the default now
(defun minibuffer-complete ()
  "Complete the minibuffer contents as far as possible.
Return nil if there is no valid completion, else t.
If no characters can be completed, display a list of possible completions.
If you repeat this command after it displayed such a list,
scroll the window of possible completions."
  (interactive)
  ;; If the previous command was not this,
  ;; mark the completion buffer obsolete.
  (setq this-command 'completion-at-point)
  (unless (eq 'completion-at-point last-command)
    (completion--flush-all-sorted-completions)
    (setq minibuffer-scroll-window nil))

  (let ((window minibuffer-scroll-window))
    ;; If there's a fresh completion window with a live buffer,
    ;; and this command is repeated, scroll that window.
    (if (window-live-p window)
        (with-current-buffer (window-buffer window)
          (if (pos-visible-in-window-p (point-max) window)
	      ;; If end is in view, scroll up to the beginning.
	      (set-window-start window (point-min) nil)
	    ;; Else scroll down one screen.
	    (scroll-other-window))
	  nil)

      (case (completion--do-completion)
        (#b000 nil)
        (#b001 (goto-char (field-end))
               (minibuffer-message "Sole completion")
               t)
        (#b011 ;; (goto-char (field-end)) ; ELI: no idea why this was done
               (minibuffer-message "Complete, but not unique")
               t)
        (t     t)))))

;;-----------------------------------------------------------------------------
;; Overrides from "complete.el": short messages, a little saner treatment for
;; case-insensitive

' ;; looks like this is all the default now -- ?
(eval-after-load "complete" '(progn

(defun PC-temp-minibuffer-message (message)
  "A Lisp version of `temp_minibuffer_message' from minibuf.c."
  (let ((delay (if (string-match "Complete.*not unique" message) 0.15 0.5)))
    (cond (PC-not-minibuffer
           (message message)
           (sit-for delay)
           (message ""))
          ((fboundp 'temp-minibuffer-message)
           (temp-minibuffer-message message))
          (t (let ((point-max (point-max)))
               (save-excursion (goto-char point-max)
                               (insert message))
               (let ((inhibit-quit t))
                 (sit-for delay)
                 (delete-region point-max (point-max))
                 (when quit-flag
                   (setq quit-flag nil
                         unread-command-events '(7)))))))))

(defun PC-do-completion (&optional mode beg end goto-end)
  "Internal function to do the work of partial completion.
Text to be completed lies between BEG and END.  Normally when
replacing text in the minibuffer, this function replaces up to
point-max (as is appropriate for completing a file name).  If
GOTO-END is non-nil, however, it instead replaces up to END."
  (or beg (setq beg (minibuffer-prompt-end)))
  (or end (setq end (point-max)))
  (let* ((table minibuffer-completion-table)
	 (pred minibuffer-completion-predicate)
	 (filename (funcall PC-completion-as-file-name-predicate))
	 (dirname nil) ; non-nil only if a filename is being completed
	 ;; The following used to be "(dirlength 0)" which caused the erasure of
	 ;; the entire buffer text before `point' when inserting a completion
	 ;; into a buffer.
	 dirlength
	 (str (buffer-substring beg end))
	 (incname (and filename (string-match "<\\([^\"<>]*\\)>?$" str)))
	 (ambig nil)
	 basestr origstr
	 env-on
	 regex
	 p offset
	 (poss nil)
	 helpposs
	 (case-fold-search completion-ignore-case))

    ;; Check if buffer contents can already be considered complete
    (if (and (eq mode 'exit)
	     (test-completion str table pred))
	(progn
	  ;; If completion-ignore-case is non-nil, insert the
	  ;; completion string since that may have a different case.
	  (when completion-ignore-case
	    (setq str (PC-try-completion str table pred))
	    (delete-region beg end)
	    (insert str))
	  'complete)

      ;; Do substitutions in directory names
      (and filename
           (setq basestr (or (file-name-directory str) ""))
           (setq dirlength (length basestr))
	   ;; Do substitutions in directory names
           (setq p (substitute-in-file-name basestr))
           (not (string-equal basestr p))
           (setq str (concat p (file-name-nondirectory str)))
           (progn
	     (delete-region beg end)
	     (insert str)
	     (setq end (+ beg (length str)))))

      ;; Prepare various delimiter strings
      (or (equal PC-word-delimiters PC-delims)
	  (setq PC-delims PC-word-delimiters
		PC-delim-regex (concat "[" PC-delims "]")
		PC-ndelims-regex (concat "[^" PC-delims "]*")
		PC-delims-list (append PC-delims nil)))

      ;; Add wildcards if necessary
      (and filename
           (let ((dir (file-name-directory str))
                 (file (file-name-nondirectory str))
		 ;; The base dir for file-completion is passed in `predicate'.
		 (default-directory (expand-file-name pred)))
             (while (and (stringp dir) (not (file-directory-p dir)))
               (setq dir (directory-file-name dir))
               (setq file (concat (replace-regexp-in-string
                                   PC-delim-regex "*\\&"
                                   (file-name-nondirectory dir))
                                  "*/" file))
               (setq dir (file-name-directory dir)))
             (setq origstr str str (concat dir file))))

      ;; Look for wildcard expansions in directory name
      (and filename
	   (string-match "\\*.*/" str)
	   (let ((pat str)
		 ;; The base dir for file-completion is passed in `predicate'.
		 (default-directory (expand-file-name pred))
		 files)
	     (setq p (1+ (string-match "/[^/]*\\'" pat)))
	     (while (setq p (string-match PC-delim-regex pat p))
	       (setq pat (concat (substring pat 0 p)
				 "*"
				 (substring pat p))
		     p (+ p 2)))
	     (setq files (file-expand-wildcards (concat pat "*"))) ;ELI
	     (if files
		 (let ((dir (file-name-directory (car files)))
		       (p files))
		   (while (and (setq p (cdr p))
			       (equal dir (file-name-directory (car p)))))
		   (if p
		       (setq filename nil table nil pred nil
			     ambig t)
		     (delete-region beg end)
		     (setq str (concat dir (file-name-nondirectory str)))
		     (insert str)
		     (setq end (+ beg (length str)))))
	       (if origstr
                   ;; If the wildcards were introduced by us, it's possible
                   ;; that read-file-name-internal (especially our
                   ;; PC-include-file advice) can still find matches for the
                   ;; original string even if we couldn't, so remove the
                   ;; added wildcards.
                   (setq str origstr)
		 (setq filename nil table nil pred nil)))))

      ;; Strip directory name if appropriate
      (if filename
	  (if incname
	      (setq basestr (substring str incname)
		    dirname (substring str 0 incname))
	    (setq basestr (file-name-nondirectory str)
		  dirname (file-name-directory str))
	    ;; Make sure str is consistent with its directory and basename
	    ;; parts.  This is important on DOZe'NT systems when str only
	    ;; includes a drive letter, like in "d:".
	    (setq str (concat dirname basestr)))
	(setq basestr str))

      ;; Convert search pattern to a standard regular expression
      (setq regex (regexp-quote basestr)
	    offset (if (and (> (length regex) 0)
			    (not (eq (aref basestr 0) ?\*))
			    (or (eq PC-first-char t)
				(and PC-first-char filename))) 1 0)
	    p offset)
      (while (setq p (string-match PC-delim-regex regex p))
	(if (eq (aref regex p) ? )
	    (setq regex (concat (substring regex 0 p)
				PC-ndelims-regex
				PC-delim-regex
				(substring regex (1+ p)))
		  p (+ p (length PC-ndelims-regex) (length PC-delim-regex)))
	  (let ((bump (if (memq (aref regex p)
				'(?$ ?^ ?\. ?* ?+ ?? ?[ ?] ?\\))
			  -1 0)))
	    (setq regex (concat (substring regex 0 (+ p bump))
				PC-ndelims-regex
				(substring regex (+ p bump)))
		  p (+ p (length PC-ndelims-regex) 1)))))
      (setq p 0)
      (if filename
	  (while (setq p (string-match "\\\\\\*" regex p))
	    (setq regex (concat (substring regex 0 p)
				"[^/]*"
				(substring regex (+ p 2))))))
      ;;(setq the-regex regex)
      (setq regex (concat "\\`" regex))

      (and (> (length basestr) 0)
           (= (aref basestr 0) ?$)
           (setq env-on t
                 table PC-env-vars-alist
                 pred nil))

      ;; Find an initial list of possible completions
      (if (not (setq p (string-match (concat PC-delim-regex
					     (if filename "\\|\\*" ""))
				     str
				     (+ (length dirname) offset))))

	  ;; Minibuffer contains no hyphens -- simple case!
	  (setq poss (all-completions (if env-on
					  basestr str)
				      table
				      pred))

	;; Use all-completions to do an initial cull.  This is a big win,
	;; since all-completions is written in C!
	(let ((compl (all-completions (if env-on
					  (file-name-nondirectory (substring str 0 p))
					(substring str 0 p))
                                      table
                                      pred)))
	  (setq p compl)
	  (while p
	    (and (string-match regex (car p))
		 (progn
		   (set-text-properties 0 (length (car p)) '() (car p))
		   (setq poss (cons (car p) poss))))
	    (setq p (cdr p)))))

      ;; ELI: hack -- if no options, and the string is ~something, use passwd
      (when (and filename (null poss) (equal ?~ (elt str 0)))
        (setq poss (let* ((sofar (substring str 1))
                          (len   (length sofar)))
                     (mapcar (lambda (x) (concat "~" (car x) "/"))
                             (filter (lambda (u-h)
                                       (let ((user (car u-h)))
                                         (and (<= len (length user))
                                              (equal sofar
                                                     (substring user 0 len)))))
                                     eli-user-homedirs)))))


      ;; If table had duplicates, they can be here.
      (delete-dups poss)

      ;; Handle completion-ignored-extensions
      (and filename
           (not (eq mode 'help))
           (let ((p2 poss))

             ;; Build a regular expression representing the extensions list
             (or (equal completion-ignored-extensions PC-ignored-extensions)
                 (setq PC-ignored-regexp
                       (concat "\\("
                               (mapconcat
                                'regexp-quote
                                (setq PC-ignored-extensions
                                      completion-ignored-extensions)
                                "\\|")
                               "\\)\\'")))

             ;; Check if there are any without an ignored extension.
             ;; Also ignore `.' and `..'.
             (setq p nil)
             (while p2
               (or (string-match PC-ignored-regexp (car p2))
                   (string-match "\\(\\`\\|/\\)[.][.]?/?\\'" (car p2))
                   (setq p (cons (car p2) p)))
               (setq p2 (cdr p2)))

             ;; If there are "good" names, use them
             (and p (setq poss p))))

      ;; Now we have a list of possible completions
      (cond

       ;; No valid completions found
       ((null poss)
	(if (and (eq mode 'word)
		 (not PC-word-failed-flag))
	    (let ((PC-word-failed-flag t))
	      (delete-backward-char 1)
	      (PC-do-completion 'word))
	  (beep)
	  (PC-temp-minibuffer-message (if ambig
					  " [Ambiguous dir name]"
					(if (eq mode 'help)
					    " [No completions]"
					  " [No match]")))
	  nil))

       ;; More than one valid completion found
       ((or (cdr (setq helpposs poss))
	    (memq mode '(help word)))

	;; Is the actual string one of the possible completions?
	(setq p (and (not (eq mode 'help)) poss))
	(while (and p
		    (not (string-equal (car p) basestr)))
	  (setq p (cdr p)))
	(and p (null mode)
	     (PC-temp-minibuffer-message " [Complete, but not unique]"))
	(if (and p
		 (not (and (null mode)
			   (eq this-command last-command))))
	    t

	  ;; If ambiguous, try for a partial completion
	  (let ((improved nil)
		prefix
		(pt nil)
		(skip "\\`"))

	    ;; Check if next few letters are the same in all cases
	    (if (and (not (eq mode 'help))
		     (setq prefix (PC-try-completion
				   (PC-chunk-after basestr skip) poss)))
		(let ((first t) i)
                  ;;ELI: If there are possibility prefixes that match the
                  ;; basestr exactly then replace the basestr part of prefix by
                  ;; the apropriate one.
                  (when completion-ignore-case
                    (let* ((completion-ignore-case nil)
                           (poss (all-completions basestr (mapcar 'list poss)))
                           (case-prefix
                            (try-completion "" (mapcar 'list poss))))
                      (when case-prefix
                        (when (> (length case-prefix) (length prefix))
                          (setq case-prefix
                                (substring case-prefix 0 (length prefix))))
                        (setq prefix
                              (concat
                               case-prefix
                               (substring prefix (length case-prefix)))))))
		  ;; Retain capitalization of user input even if
		  ;; completion-ignore-case is set.
                  ;; ELI: tweak this in a horrible-ununderstood way, basically
                  ;; using older code that does not try to be smart in a broken
                  ;; way
		  (if (eq mode 'word)
		      (setq prefix (PC-chop-word prefix basestr)))
		  (goto-char (+ beg (length dirname)))
                  (while (and (progn
				(setq i 0) ; index into prefix string
				(while (< i (length prefix))
				  (if (and (< (point) end)
					   (eq (aref prefix i) ; ELI: done above
					       (following-char)))
				      ;; same char (modulo case); no action
				      (forward-char 1)
				    (if (and (< (point) end)
					     (or (and (looking-at " ")
						      (memq (aref prefix i)
							    PC-delims-list))
						 (eq (downcase (aref prefix i))
						     (downcase
						      (following-char)))))
					;; replace " " by the actual delimiter
					(progn
					  (delete-char 1)
					  (setq end (1- end)))
				      ;; insert a new character
				      (progn
                                        (and filename (looking-at "\\*")
                                             (progn
                                               (delete-char 1)
                                               (setq end (1- end))))
					(setq improved t)))
                                    (insert (substring prefix i (1+ i)))
                                    (setq end (1+ end)))
				  (setq i (1+ i)))
				(or pt (setq pt (point)))
				(looking-at PC-delim-regex))
			      (setq skip (concat skip
						 (regexp-quote prefix)
						 PC-ndelims-regex)
				    prefix (PC-try-completion
					    (PC-chunk-after
					     ;; not basestr, because that does
					     ;; not reflect insertions
					     (buffer-substring
					      (+ beg (length dirname)) end)
					     skip)
					    (mapcar
                                             (lambda (x)
                                               (when (string-match skip x)
                                                 (substring x (match-end 0))))
					     poss)))
			      (or (> i 0) (> (length prefix) 0))
			      (or (not (eq mode 'word))
				  (and first (> (length prefix) 0)
				       (setq first nil
					     prefix (substring prefix 0 1))))))
		  (goto-char (if (eq mode 'word) end
			       (or pt beg)))))

	    (if (and (eq mode 'word)
		     (not PC-word-failed-flag))

		(if improved

		    ;; We changed it... would it be complete without the space?
		    (if (test-completion (buffer-substring 1 (1- end))
                                         table pred)
			(delete-region (1- end) end)))

	      (if improved

		  ;; We changed it... enough to be complete?
		  (and (eq mode 'exit)
		       (test-completion-ignore-case (field-string) table pred))

		;; If totally ambiguous, display a list of completions
		(if (or (eq completion-auto-help t)
			(and completion-auto-help
			     (eq last-command this-command))
			(eq mode 'help))
                    (let ((prompt-end (minibuffer-prompt-end)))
                      (with-output-to-temp-buffer "*Completions*"
                        (display-completion-list (sort helpposs 'string-lessp))
                        (setq PC-do-completion-end end
                              PC-goto-end goto-end)
                        (with-current-buffer standard-output
                          ;; Record which part of the buffer we are completing
                          ;; so that choosing a completion from the list
                          ;; knows how much old text to replace.
                          ;; This was briefly nil in the non-dirname case.
                          ;; However, if one calls PC-lisp-complete-symbol
                          ;; on "(ne-f" with point on the hyphen, PC offers
                          ;; all completions starting with "(ne", some of
                          ;; which do not match the "-f" part (maybe it
                          ;; should not, but it does). In such cases,
                          ;; completion gets confused trying to figure out
                          ;; how much to replace, so we tell it explicitly
                          ;; (ie, the number of chars in the buffer before beg).
                          ;;
                          ;; Note that choose-completion-string-functions
                          ;; plays around with point.
                          (setq completion-base-size (if dirname
                                                         dirlength
                                                       (- beg prompt-end))))))
		  (PC-temp-minibuffer-message " [Next char not unique]"))
		nil)))))

       ;; Only one possible completion
       (t
	(if (and (equal basestr (car poss))
		 (not (and env-on filename)))
	    (if (null mode)
		(PC-temp-minibuffer-message " [Sole completion]"))
	  (delete-region beg end)
	  (insert (format "%s"
			  (if filename
			      (substitute-in-file-name (concat dirname (car poss)))
			    (car poss)))))
	t)))))

))

;; Since PC-complete is still bad, easier to just do the hack in the above
;; ;; Match on usernames -- done similarly to include files in "complete.el")
;; ;; using an advice (no need for a hook on `find-file-not-found-functions' since
;; ;; these paths do exist).  (All of this is barely-documented stuff.)
;; (defadvice read-file-name-internal (around PC-eli-usernames activate compile)
;;   (if (string-match "~\\([^/]*\\)\\'" (ad-get-arg 0))
;;     (let* ((string (ad-get-arg 0))
;;            ;; (dir (ad-get-arg 1)) <-- not needed
;;            (action (ad-get-arg 2))
;;            (name (match-string 1 string))
;;            (str2 (substring string (match-beginning 0)))
;;            (completion-table (mapcar (lambda (x) (concat "~" (car x) "/"))
;;                                      eli-user-homedirs)))
;;       (setq ad-return-value
;;             (cond
;;               ((not completion-table) nil)
;;               ((eq action 'lambda) (test-completion str2 completion-table nil))
;;               ((eq action nil) (PC-try-completion str2 completion-table nil))
;;               ((eq action t) (all-completions str2 completion-table nil)))))
;;     ad-do-it))

;;-----------------------------------------------------------------------------
;; Overrides from "isearch.el": make `isearch-allow-scroll' not remove shift
;; modifiers, so it plays nicely with cua-mode.  Also, make scroll keys simply
;; leave isearch if the point goes out of the screen.

(defun isearch-reread-key-sequence-naturally (keylist)
  "Reread key sequence KEYLIST with an inactive Isearch-mode keymap.
Return the key sequence as a string/vector."
  (isearch-unread-key-sequence keylist)
  (let (overriding-terminal-local-map)
    ;; This will go through function-key-map, if nec.
    (read-key-sequence nil nil t))) ;ELI: Add the t

(defun isearch-other-meta-char (&optional arg)
  "Process a miscellaneous key sequence in Isearch mode.

Try to convert the current key-sequence to something usable in Isearch
mode, either by converting it with `function-key-map', downcasing a
key with C-<upper case>, or finding a \"scrolling command\" bound to
it.  \(In the last case, we may have to read more events.)  If so,
either unread the converted sequence or execute the command.

Otherwise, if `search-exit-option' is non-nil (the default) unread the
key-sequence and exit the search normally.  If it is the symbol
`edit', the search string is edited in the minibuffer and the meta
character is unread so that it applies to editing the string.

ARG is the prefix argument.  It will be transmitted through to the
scrolling command or to the command whose key-sequence exits
Isearch mode."
  (interactive "P")
  (let* ((key (if current-prefix-arg    ; not nec the same as ARG
                  (substring (this-command-keys) universal-argument-num-events)
                (this-command-keys)))
	 (main-event (aref key 0))
	 (keylist (listify-key-sequence key))
         scroll-command isearch-point)
    (cond ((and (= (length key) 1)
		(let ((lookup (lookup-key local-function-key-map key)))
		  (not (or (null lookup) (integerp lookup)
			   (keymapp lookup)))))
	   ;; Handle a function key that translates into something else.
	   ;; If the key has a global definition too,
	   ;; exit and unread the key itself, so its global definition runs.
	   ;; Otherwise, unread the translation,
	   ;; so that the translated key takes effect within isearch.
	   (cancel-kbd-macro-events)
	   (if (lookup-key global-map key)
	       (progn
		 (isearch-done)
		 (setq prefix-arg arg)
		 (apply 'isearch-unread keylist))
	     (setq keylist
		   (listify-key-sequence (lookup-key local-function-key-map key)))
	     (while keylist
	       (setq key (car keylist))
	       ;; If KEY is a printing char, we handle it here
	       ;; directly to avoid the input method and keyboard
	       ;; coding system translating it.
	       (if (and (integerp key)
			(>= key ?\s) (/= key 127) (< key 256))
		   (progn
		     (isearch-process-search-char key)
		     (setq keylist (cdr keylist)))
		 ;; As the remaining keys in KEYLIST can't be handled
		 ;; here, we must reread them.
		 (setq prefix-arg arg)
		 (apply 'isearch-unread keylist)
		 (setq keylist nil)))))
	  (
	   ;; Handle an undefined shifted control character
	   ;; by downshifting it if that makes it defined.
	   ;; (As read-key-sequence would normally do,
	   ;; if we didn't have a default definition.)
	   (let ((mods (event-modifiers main-event)))
	     (and (integerp main-event)
		  (memq 'shift mods)
		  (memq 'control mods)
		  (not (memq (lookup-key isearch-mode-map
					 (let ((copy (copy-sequence key)))
					   (aset copy 0
						 (- main-event
						    (- ?\C-\S-a ?\C-a)))
					   copy)
					 nil)
			     '(nil
			       isearch-other-control-char)))))
	   (setcar keylist (- main-event (- ?\C-\S-a ?\C-a)))
	   (cancel-kbd-macro-events)
	   (setq prefix-arg arg)
	   (apply 'isearch-unread keylist))
	  ((eq search-exit-option 'edit)
	   (setq prefix-arg arg)
	   (apply 'isearch-unread keylist)
	   (isearch-edit-string))
          ;; ELI: The following branch is moved here for convenience
	  ;; A mouse click on the isearch message starts editing the search string
	  ((and (eq (car-safe main-event) 'down-mouse-1)
		(window-minibuffer-p (posn-window (event-start main-event))))
	   ;; Swallow the up-event.
	   (read-event)
	   (isearch-edit-string))
          ;; Handle a scrolling function.
          ((and isearch-allow-scroll
                (progn (setq key (isearch-reread-key-sequence-naturally keylist))
                       (setq keylist (listify-key-sequence key))
                       (setq main-event (aref key 0))
                       (setq scroll-command (isearch-lookup-scroll-key key))))
           ;; From this point onwards, KEY, KEYLIST and MAIN-EVENT hold a
           ;; complete key sequence, possibly as modified by function-key-map,
           ;; not merely the one or two event fragment which invoked
           ;; isearch-other-meta-char in the first place.
           (setq isearch-point (point))
           (setq prefix-arg arg)
           (command-execute scroll-command)
           (let ((ab-bel (isearch-string-out-of-window isearch-point)))
             (if ab-bel
                 ;; ELI: if got out of window -- get out of isearch
                 ;; (isearch-back-into-window (eq ab-bel 'above) isearch-point)
                 ;; This is an exact copy of the next case, except for the
                 ;; keyboard stuff
                 (let (window)
                   ;; (isearch-unread-key-sequence keylist)
                   ;; (setq main-event (car unread-command-events))
                   (if (and (not isearch-mode)
                            (listp main-event)
                            (setq window (posn-window (event-start main-event)))
                            (windowp window)
                            (or (> (minibuffer-depth) 0)
                                (not (window-minibuffer-p window))))
                     (with-current-buffer (window-buffer window)
                       (isearch-done)
                       (isearch-clean-overlays))
                     (isearch-done)
                     (isearch-clean-overlays)
                     (setq prefix-arg arg)))
               (goto-char isearch-point)
               (isearch-update)))) ; ELI: moved inside here
	  (search-exit-option
	   (let (window)
	     (setq prefix-arg arg)
             (isearch-unread-key-sequence keylist)
             (setq main-event (car unread-command-events))

	     ;; If we got a mouse click event, that event contains the
	     ;; window clicked on. maybe it was read with the buffer
	     ;; it was clicked on.  If so, that buffer, not the current one,
	     ;; is in isearch mode.  So end the search in that buffer.

	     ;; ??? I have no idea what this if checks for, but it's
	     ;; obviously wrong for the case that a down-mouse event
	     ;; on another window invokes this function.  The event
	     ;; will contain the window clicked on and that window's
	     ;; buffer is certainly not always in Isearch mode.
	     ;;
	     ;; Leave the code in, but check for current buffer not
	     ;; being in Isearch mode for now, until someone tells
	     ;; what it's really supposed to do.
	     ;;
	     ;; --gerd 2001-08-10.

	     (if (and (not isearch-mode)
		      (listp main-event)
		      (setq window (posn-window (event-start main-event)))
		      (windowp window)
		      (or (> (minibuffer-depth) 0)
			  (not (window-minibuffer-p window))))
		 (with-current-buffer (window-buffer window)
		   (isearch-done)
		   (isearch-clean-overlays))
	       (isearch-done)
	       (isearch-clean-overlays)
               (setq prefix-arg arg))))
          (t;; otherwise nil
	   (isearch-process-search-string key key)))))

;;; override.el ends here
