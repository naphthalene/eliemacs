;;; shell-utils.el --- Shell related utilities
;;-----------------------------------------------------------------------------
;; Written by Eli Barzilay: Maze is Life!   (eli@barzilay.org)

;; Usually, the shell buffer is entered through `pop-to-buffer', which doesn't
;; leave it at the top -- this hack makes sure it is selected (better to avoid
;; surprises when switching buffers).
(add-hook 'shell-mode-hook (lambda () (switch-to-buffer (current-buffer))))

;;-----------------------------------------------------------------------------
;; Friendlier `shell' and `shell-command'

(defvar eli-last-shell nil)

(defun eli-shell (arg)
  "Similar to `shell' but extended as follows:
- a positive numeric argument means jump to that shell window,
  with 1 being the default \"*shell*\", 2 is \"*shell*<2>\" etc,
- a 0 numeric argument will jump to a new shell window (the next
  one), without asking about the name,
- no argument means jump to the last shell window,
- it switches to the buffer as usual, in the current window: no
  switching to a half-screen, and preserve the buffer visit
  history so there's no inconsistent buffer switching
  later."
  (interactive "P")
  (switch-to-buffer
   (save-window-excursion
     (cond ((and (integerp arg) (>= arg 0))
            (shell (setq eli-last-shell
                         (cond ((= arg 0) (generate-new-buffer-name "*shell*"))
                               ((= arg 1) "*shell*")
                               (t (format "*shell*<%S>" arg))))))
           ((and eli-last-shell (not arg)) (shell eli-last-shell))
           (t (call-interactively 'shell))))))

(defun eli-shell-command ()
  "Similar to `shell-command' but sets environment variables $f, $F, and $d
to the current file's name, fullname,and directory name (if the current
buffer is associated with a file).  Also, use the region if it is on."
  (interactive)
  (let ((max-mini-window-height 1) ; make it more predictable
        (process-environment process-environment)) ; restore the env later
    (cond ((buffer-file-name)
           (setenv "f" (file-name-nondirectory (buffer-file-name)))
           (setenv "F" (buffer-file-name))
           (setenv "d" (file-name-directory (buffer-file-name))))
          (t (setenv "d" default-directory)))
    (call-interactively
     (if (use-region-p) 'shell-command-on-region 'shell-command))))

;;-----------------------------------------------------------------------------
;; * Make it possible for comint to send input immediately.
;; * Convenient C-up/C-down keys for history or navigation in comint

(defun comint-send-now ()
  "Send everything written so far immediately."
  (interactive)
  ;; Note that the input string does not include its terminal newline.
  (let ((proc (get-buffer-process (current-buffer))))
    (if (not proc)
      (error "Current buffer has no process")
      (let* ((pmark (process-mark proc))
             (input (progn (goto-char (point-max))
                           (buffer-substring pmark (point)))))
        (when comint-process-echoes
          (delete-region pmark (point)))
        (run-hook-with-args 'comint-input-filter-functions input)
        (set-marker comint-last-input-start pmark)
        (set-marker comint-last-input-end (point))
        (set-marker (process-mark proc) (point))
        (set-marker comint-accum-marker nil)
        (comint-send-string proc input)
        (run-hook-with-args 'comint-output-filter-functions "")))))

(defun comint-quoted-send ()
  "Read a character the same way as quoted-insert does, then send it
immediately to the process using `comint-send-now' (so previous input
must be sent as well)."
  (interactive)
  (message "Enter a character...")
  (insert-and-inherit (read-quoted-char))
  (comint-send-now))

(defun comint-previous-matching-input-from-input-or-scroll (n)
  (interactive "p")
  (if (comint-after-pmark-p)
    (progn (setq this-command 'comint-previous-matching-input-from-input)
           (comint-previous-matching-input-from-input n))
    (scroll-down-1-stay n)))

(defun comint-next-matching-input-from-input-or-scroll (n)
  (interactive "p")
  (if (comint-after-pmark-p)
    (progn (setq this-command 'comint-next-matching-input-from-input)
           (comint-next-matching-input-from-input n))
    (scroll-up-1-stay n)))

(eval-after-load "comint"
  '(define-keys comint-mode-map
     '([(meta q)] 'comint-quoted-send)
     '([(control up)]   comint-previous-matching-input-from-input-or-scroll)
     '([(control down)] comint-next-matching-input-from-input-or-scroll)))

;;; shell-utils.el ends here
