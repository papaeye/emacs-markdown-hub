;;; markdown-hub.el --- Markdown Hub publisher       -*- lexical-binding: t; -*-

;; Copyright (C) 2015 by Syohei YOSHIDA
;; Copyright (C) 2015  papaeye

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; Maintainer: papaeye <papaeye@gmail.com>
;; Keywords: convenience
;; Version: 0.1.0
;; Homepage: https://github.com/papaeye/emacs-markdown-hub
;; Package-Requires: ((emacs "24.4") (websocket "1.4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'websocket)

(defgroup markdown-hub nil
  "Markdown Hub publisher"
  :group 'text)

;;; Customization

(defcustom markdown-hub-docker-command "docker"
  "The default Docker command."
  :type 'string
  :group 'markdown-hub)

(defcustom markdown-hub-docker-image "papaeye/markdown-hub"
  "The default Docker image name."
  :type 'string
  :group 'markdown-hub)

(defcustom markdown-hub-docker-container "markdown-hub"
  "The default Docker container name."
  :type 'string
  :group 'markdown-hub)

(defcustom markdown-hub-hostname "127.0.0.1"
  "The default Docker container hostname.

If the value is `boot2docker', it is substituted by $(boot2docker ip)."
  :type '(choice string
                 (const :tag "Use $(boot2docker ip)") boot2docker)
  :group 'markdown-hub)

(defcustom markdown-hub-port 5021
  "The default Docker container port."
  :type 'integer
  :group 'markdown-hub)

(defcustom markdown-hub-renderer 'gfm
  "The default Markdown renderer."
  :type '(choice (const :tag "Plain Markdown" plain)
                 (const :tag "GitHub-flavored Markdown") gfm)
  :group 'markdown-hub)
(make-variable-buffer-local 'markdown-hub-renderer)

(defcustom markdown-hub-browser-function #'browse-url
  "Function to display the top page of Markdown Hub."
  :type 'function
  :group 'markdown-hub)

(defun markdown-hub-host ()
  (let ((hostname markdown-hub-hostname))
    (when (eq hostname 'boot2docker)
      (setq hostname (shell-command-to-string "boot2docker ip"))
      (when (string-match "[ \t\r\n]+\\'" hostname)
        (setq hostname (replace-match "" t t hostname))))
    (format "%s:%d" hostname markdown-hub-port)))

(defun markdown-hub-url ()
  (format "http://%s/" (markdown-hub-host)))

(defun markdown-hub-ws-url ()
  (format "ws://%s/%s"
          (markdown-hub-host)
          (symbol-name markdown-hub-renderer)))

;;; WebSocket

(defvar markdown-hub-websocket nil)
(make-variable-buffer-local 'markdown-hub-websocket)

(defun markdown-hub-open ()
  (let ((url (markdown-hub-ws-url)))
    (message "Connecting to %s..." url)
    (setq markdown-hub-websocket
          (websocket-open url
                          :on-open (lambda (websocket)
                                     (message "Connecting to %s...done"
                                              (websocket-url websocket)))))))

(defun markdown-hub-close ()
  (when markdown-hub-websocket
    (websocket-close markdown-hub-websocket)
    (setq markdown-hub-websocket nil)))

(defvar markdown-hub-mode)
(defun markdown-hub-send ()
  (when markdown-hub-mode
    (let ((str (buffer-substring-no-properties (point-min) (point-max))))
      (websocket-send-text markdown-hub-websocket str))))

;;; Docker

(defun markdown-hub--docker-buffer ()
  (get-buffer-create "*markdown hub docker*"))

(defun markdown-hub--docker-command (message &rest args)
  (when message
    (message "%s..." message))
  (with-current-buffer (markdown-hub--docker-buffer)
    (erase-buffer)
    (if (zerop (apply #'call-process markdown-hub-docker-command
                      nil t nil args))
        (when message
          (message "%s...done" message))
      (when message
        (message "%s...failed" message))
      (error "The Docker command `%s %s' failed"
             markdown-hub-docker-command
             (mapconcat #'identity args " ")))))

(defun markdown-hub--container-exists-p (&optional running)
  (let* ((filter (format "name=%s" markdown-hub-docker-container))
         (args (nconc (list "ps" "--quiet" "--filter" filter)
                      (unless running (list "--all")))))
    (apply #'markdown-hub--docker-command nil args)
    (with-current-buffer (markdown-hub--docker-buffer)
      (not (string= (buffer-string) "")))))

(defun markdown-hub--container-running-p ()
  (markdown-hub--container-exists-p 'running))

(defun markdown-hub--container-stopped-p ()
  ;; This function is not self-contained, but improves the readability of
  ;; `markdown-hub-ensure-running'.
  (markdown-hub--container-exists-p))

(defun markdown-hub--container-start ()
  (let ((args (list "run"
                    "--detach"
                    "--publish" (format "%d:9292" markdown-hub-port)
                    "--name" markdown-hub-docker-container
                    markdown-hub-docker-image)))
    (apply #'markdown-hub--docker-command
           "Starting the Docker container" args)))

(defun markdown-hub--container-restart ()
  (markdown-hub--docker-command "Restarting the Docker container"
                                "restart" markdown-hub-docker-container))

(defun markdown-hub--container-stop ()
  (markdown-hub--docker-command "Stopping the Docker container"
                                "stop" markdown-hub-docker-container))

(defun markdown-hub-ensure-running ()
  (unless (markdown-hub--container-running-p)
    (if (markdown-hub--container-stopped-p)
        (markdown-hub--container-restart)
      (markdown-hub--container-start))
    (sleep-for 1)))

(defun markdown-hub-stop-container ()
  (when (markdown-hub--container-running-p)
    (markdown-hub--container-stop)))

;;; Minor mode

(defun markdown-hub-setup ()
  (markdown-hub-ensure-running)
  (markdown-hub-open)
  (add-hook 'kill-emacs-hook #'markdown-hub-stop-container)
  (add-hook 'post-command-hook #'markdown-hub-send nil t))

(defun markdown-hub-teardown ()
  (remove-hook 'post-command-hook #'markdown-hub-send t)
  (markdown-hub-close))

;;;###autoload
(define-minor-mode markdown-hub-mode nil
  :group 'markdown-hub
  (if markdown-hub-mode
      (markdown-hub-setup)
    (markdown-hub-teardown)))

;;;###autoload
(defun markdown-hub-browse ()
  "Browse the top page of Markdown Hub with `markdown-hub-browser-function'."
  (interactive)
  (markdown-hub-ensure-running)
  (funcall markdown-hub-browser-function (markdown-hub-url)))

(provide 'markdown-hub)
;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; markdown-hub.el ends here
