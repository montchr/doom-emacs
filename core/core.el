;;; core.el --- the heart of the beast -*- lexical-binding: t; -*-

(when (version< emacs-version "25.3")
  (error "Detected Emacs %s. Doom only supports Emacs 25.3 and higher"
         emacs-version))

(defconst doom-version "2.0.9"
  "Current version of Doom Emacs.")

(defconst EMACS26+ (> emacs-major-version 25))
(defconst EMACS27+ (> emacs-major-version 26))
(defconst IS-MAC     (eq system-type 'darwin))
(defconst IS-LINUX   (eq system-type 'gnu/linux))
(defconst IS-WINDOWS (memq system-type '(cygwin windows-nt ms-dos)))
(defconst IS-BSD     (or IS-MAC (eq system-type 'berkeley-unix)))

;; Ensure `doom-core-dir' is in `load-path'
(add-to-list 'load-path (file-name-directory load-file-name))

(defvar doom--initial-load-path load-path)
(defvar doom--initial-process-environment process-environment)
(defvar doom--initial-exec-path exec-path)
(defvar doom--initial-file-name-handler-alist file-name-handler-alist)

;; This is consulted on every `require', `load' and various path/io functions.
;; You get a minor speed up by nooping this.
(setq file-name-handler-alist nil)

;; Load the bare necessities
(require 'core-lib)


;;
;;; Global variables

(defvar doom-init-p nil
  "Non-nil if Doom has been initialized.")

(defvar doom-init-time nil
  "The time it took, in seconds, for Doom Emacs to initialize.")

(defvar doom-debug-mode (or (getenv "DEBUG") init-file-debug)
  "If non-nil, Doom will log more.

Use `doom/toggle-debug-mode' to toggle it. The --debug-init flag and setting the
DEBUG envvar will enable this at startup.")

(defvar doom-interactive-mode (not noninteractive)
  "If non-nil, Emacs is in interactive mode.")

(defvar doom-gc-cons-threshold 16777216 ; 16mb
  "The default value to use for `gc-cons-threshold'. If you experience freezing,
decrease this. If you experience stuttering, increase this.")

;;; Directories/files
(defvar doom-emacs-dir
  (eval-when-compile (file-truename user-emacs-directory))
  "The path to the currently loaded .emacs.d directory. Must end with a slash.")

(defvar doom-core-dir (concat doom-emacs-dir "core/")
  "The root directory of Doom's core files. Must end with a slash.")

(defvar doom-modules-dir (concat doom-emacs-dir "modules/")
  "The root directory for Doom's modules. Must end with a slash.")

(defvar doom-local-dir
  (if-let (localdir (getenv "DOOMLOCALDIR"))
      (file-name-as-directory localdir)
    (concat doom-emacs-dir ".local/"))
  "Root directory for local storage.

Use this as a storage location for this system's installation of Doom Emacs.
These files should not be shared across systems. By default, it is used by
`doom-etc-dir' and `doom-cache-dir'. Must end with a slash.")

(defvar doom-etc-dir (concat doom-local-dir "etc/")
  "Directory for non-volatile local storage.

Use this for files that don't change much, like server binaries, external
dependencies or long-term shared data. Must end with a slash.")

(defvar doom-cache-dir (concat doom-local-dir "cache/")
  "Directory for volatile local storage.

Use this for files that change often, like cache files. Must end with a slash.")

(defvar doom-docs-dir (concat doom-emacs-dir "docs/")
  "Where Doom's documentation files are stored. Must end with a slash.")

(defvar doom-private-dir
  (if-let (doomdir (getenv "DOOMDIR"))
      (file-name-as-directory doomdir)
    (or (let ((xdgdir
               (expand-file-name "doom/"
                                 (or (getenv "XDG_CONFIG_HOME")
                                     "~/.config"))))
          (if (file-directory-p xdgdir) xdgdir))
        "~/.doom.d/"))
  "Where your private configuration is placed.

Defaults to ~/.config/doom, ~/.doom.d or the value of the DOOMDIR envvar;
whichever is found first. Must end in a slash.")

(defvar doom-autoload-file (concat doom-local-dir "autoloads.el")
  "Where `doom-reload-core-autoloads' stores its core autoloads.

This file is responsible for informing Emacs where to find all of Doom's
autoloaded core functions (in core/autoload/*.el).")

(defvar doom-package-autoload-file (concat doom-local-dir "autoloads.pkg.el")
  "Where `doom-reload-package-autoloads' stores its package autoloads.

This file is compiled from the autoloads files of all installed packages
combined.")

(defvar doom-env-file (concat doom-local-dir "env")
  "The location of your envvar file, generated by `doom env refresh`.

This file contains environment variables scraped from your shell environment,
which is loaded at startup (if it exists). This is helpful if Emacs can't
\(easily) be launched from the correct shell session (particularly for MacOS
users).")

;;; Custom error types
(define-error 'doom-error "Error in Doom Emacs core")
(define-error 'doom-hook-error "Error in a Doom startup hook" 'doom-error)
(define-error 'doom-autoload-error "Error in an autoloads file" 'doom-error)
(define-error 'doom-module-error "Error in a Doom module" 'doom-error)
(define-error 'doom-private-error "Error in private config" 'doom-error)
(define-error 'doom-package-error "Error with packages" 'doom-error)


;;
;;; Emacs core configuration

;; Reduce debug output, well, unless we've asked for it.
(setq debug-on-error doom-debug-mode
      jka-compr-verbose doom-debug-mode)

;; UTF-8 as the default coding system
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))       ; pretty
(prefer-coding-system 'utf-8)            ; pretty
(setq locale-coding-system 'utf-8)       ; please
;; Except for the clipboard on Windows, where its contents could be in an
;; encoding that's wider than utf-8, so we let Emacs/the OS decide what encoding
;; to use.
(unless IS-WINDOWS
  (setq selection-coding-system 'utf-8)) ; with sugar on top

;; Disable warnings from legacy advice system. They aren't useful, and we can't
;; often do anything about them besides changing packages upstream
(setq ad-redefinition-action 'accept)

;; Make apropos omnipotent. It's more useful this way.
(setq apropos-do-all t)

;; Don't make a second case-insensitive pass over `auto-mode-alist'. If it has
;; to, it's our (the user's) failure. One case for all!
(setq auto-mode-case-fold nil)

;; Display the bare minimum at startup. We don't need all that noise. The
;; dashboard/empty scratch buffer is good enough.
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      inhibit-default-init t
      initial-major-mode 'fundamental-mode
      initial-scratch-message nil)
(fset #'display-startup-echo-area-message #'ignore)

;; Emacs "updates" its ui more often than it needs to, so we slow it down
;; slightly, from 0.5s:
(setq idle-update-delay 1)

;; Emacs is a huge security vulnerability, what with all the dependencies it
;; pulls in from all corners of the globe. Let's at least try to be more
;; discerning.
(setq gnutls-verify-error (getenv "INSECURE")
      tls-checktrust gnutls-verify-error
      tls-program '("gnutls-cli --x509cafile %t -p %p %h"
                    ;; compatibility fallbacks
                    "gnutls-cli -p %p %h"
                    "openssl s_client -connect %h:%p -no_ssl2 -no_ssl3 -ign_eof"))

;; Emacs stores authinfo in HOME and in plaintext. Let's not do that, mkay? This
;; file usually stores usernames, passwords, and other such treasures for the
;; aspiring malicious third party.
(setq auth-sources (list (expand-file-name "authinfo.gpg" doom-etc-dir)
                         "~/.authinfo.gpg"))

;; Emacs on Windows frequently confuses HOME (C:\Users\<NAME>) and APPDATA,
;; causing `abbreviate-home-dir' to produce incorrect paths.
(when IS-WINDOWS
  (setq abbreviated-home-dir "\\`'"))

;; Don't litter `doom-emacs-dir'
(setq abbrev-file-name             (concat doom-local-dir "abbrev.el")
      async-byte-compile-log-file  (concat doom-etc-dir "async-bytecomp.log")
      bookmark-default-file        (concat doom-etc-dir "bookmarks")
      custom-file                  (concat doom-private-dir "init.el")
      custom-theme-directory       (concat doom-private-dir "themes/")
      desktop-dirname              (concat doom-etc-dir "desktop")
      desktop-base-file-name       "autosave"
      desktop-base-lock-name       "autosave-lock"
      pcache-directory             (concat doom-cache-dir "pcache/")
      request-storage-directory    (concat doom-cache-dir "request")
      server-auth-dir              (concat doom-cache-dir "server/")
      shared-game-score-directory  (concat doom-etc-dir "shared-game-score/")
      tramp-auto-save-directory    (concat doom-cache-dir "tramp-auto-save/")
      tramp-backup-directory-alist backup-directory-alist
      tramp-persistency-file-name  (concat doom-cache-dir "tramp-persistency.el")
      url-cache-directory          (concat doom-cache-dir "url/")
      url-configuration-directory  (concat doom-etc-dir "url/")
      gamegrid-user-score-file-directory (concat doom-etc-dir "games/"))

;; HACK Stop sessions from littering the user directory
(defadvice! doom--use-cache-dir-a (session-id)
  :override #'emacs-session-filename
  (concat doom-cache-dir "emacs-session." session-id))


;;
;;; Optimizations

;; Disable bidirectional text rendering for a modest performance boost. Of
;; course, this renders Emacs unable to detect/display right-to-left languages
;; (sorry!), but for us left-to-right language speakers/writers, it's a boon.
(setq-default bidi-display-reordering 'left-to-right)

;; Reduce rendering/line scan work for Emacs by not rendering cursors or regions
;; in non-focused windows.
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; More performant rapid scrolling over unfontified regions. May cause brief
;; spells of inaccurate fontification immediately after scrolling.
(setq fast-but-imprecise-scrolling t)

;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we halve startup times, particularly when we use
;; fonts that are larger than the system default (which would resize the frame).
(setq frame-inhibit-implied-resize t)

;; Don't ping things that look like domain names.
(setq ffap-machine-p-known 'reject)

;; Performance on Windows is considerably worse than elsewhere. We'll need
;; everything we can get.
(when IS-WINDOWS
  ;; Reduce the workload when doing file IO
  (setq w32-get-true-file-attributes nil)

  ;; Font compacting can be terribly expensive, especially for rendering icon
  ;; fonts on Windows. Whether it has a noteable affect on Linux and Mac hasn't
  ;; been determined.
  (setq inhibit-compacting-font-caches t))

;; Remove command line options that aren't relevant to our current OS; that
;; means less to process at startup.
(unless IS-MAC   (setq command-line-ns-option-alist nil))
(unless IS-LINUX (setq command-line-x-option-alist nil))

;; Restore `file-name-handler-alist' because it is necessary for handling
;; encrypted or compressed files, among other things.
(defun doom-restore-file-name-handler-alist-h ()
  (setq file-name-handler-alist doom--initial-file-name-handler-alist))
(add-hook 'emacs-startup-hook #'doom-restore-file-name-handler-alist-h)

;; To speed up minibuffer commands (like helm and ivy), we defer garbage
;; collection while the minibuffer is active.
(defun doom-defer-garbage-collection-h ()
  "Increase `gc-cons-threshold' to stave off garbage collection."
  (setq gc-cons-threshold most-positive-fixnum))

(defun doom-restore-garbage-collection-h ()
  "Restore `gc-cons-threshold' to a reasonable value so the GC can do its job."
  ;; Defer it so that commands launched immediately after will enjoy the
  ;; benefits.
  (run-at-time
   1 nil (lambda () (setq gc-cons-threshold doom-gc-cons-threshold))))

(add-hook 'minibuffer-setup-hook #'doom-defer-garbage-collection-h)
(add-hook 'minibuffer-exit-hook #'doom-restore-garbage-collection-h)

;; Not restoring these to their defaults will cause stuttering/freezes.
(add-hook 'emacs-startup-hook #'doom-restore-garbage-collection-h)

;; When Emacs loses focus seems like a great time to do some garbage collection
;; all sneaky breeky like, so we can return to a fresh(er) Emacs.
(add-hook 'focus-out-hook #'garbage-collect)


;;
;;; MODE-local-vars-hook

;; File+dir local variables are initialized after the major mode and its hooks
;; have run. If you want hook functions to be aware of these customizations, add
;; them to MODE-local-vars-hook instead.
(defun doom-run-local-var-hooks-h ()
  "Run MODE-local-vars-hook after local variables are initialized."
  (run-hook-wrapped (intern-soft (format "%s-local-vars-hook" major-mode))
                    #'doom-try-run-hook))
(add-hook 'hack-local-variables-hook #'doom-run-local-var-hooks-h)

;; If the user has disabled `enable-local-variables', then
;; `hack-local-variables-hook' is never triggered, so we trigger it at the end
;; of `after-change-major-mode-hook':
(defun doom-run-local-var-hooks-if-necessary-h ()
  "Run `doom-run-local-var-hooks-h' if `enable-local-variables' is disabled."
  (unless enable-local-variables
    (doom-run-local-var-hooks-h)))
(add-hook 'after-change-major-mode-hook
          #'doom-run-local-var-hooks-if-necessary-h
          'append)


;;
;;; Incremental lazy-loading

(defvar doom-incremental-packages '(t)
  "A list of packages to load incrementally after startup. Any large packages
here may cause noticable pauses, so it's recommended you break them up into
sub-packages. For example, `org' is comprised of many packages, and can be
broken up into:

  (doom-load-packages-incrementally
   '(calendar find-func format-spec org-macs org-compat
     org-faces org-entities org-list org-pcomplete org-src
     org-footnote org-macro ob org org-clock org-agenda
     org-capture))

This is already done by the lang/org module, however.

If you want to disable incremental loading altogether, either remove
`doom-load-packages-incrementally-h' from `emacs-startup-hook' or set
`doom-incremental-first-idle-timer' to nil. Incremental loading does not occur
in daemon sessions (they are loaded immediately at startup).")

(defvar doom-incremental-first-idle-timer 2
  "How long (in idle seconds) until incremental loading starts.

Set this to nil to disable incremental loading.")

(defvar doom-incremental-idle-timer 1.5
  "How long (in idle seconds) in between incrementally loading packages.")

(defun doom-load-packages-incrementally (packages &optional now)
  "Registers PACKAGES to be loaded incrementally.

If NOW is non-nil, load PACKAGES incrementally, in `doom-incremental-idle-timer'
intervals."
  (if (not now)
      (nconc doom-incremental-packages packages)
    (while packages
      (let ((req (pop packages)))
        (unless (featurep req)
          (doom-log "Incrementally loading %s" req)
          (condition-case e
              (or (while-no-input
                    ;; If `default-directory' is a directory that doesn't exist
                    ;; or is unreadable, Emacs throws up file-missing errors, so
                    ;; we set it to a directory we know exists and is readable.
                    (let ((default-directory doom-emacs-dir)
                          (gc-cons-threshold most-positive-fixnum)
                          file-name-handler-alist)
                      (require req nil t))
                    t)
                  (push req packages))
            ((error debug)
             (message "Failed to load '%s' package incrementally, because: %s"
                      req e)))
          (if (not packages)
              (doom-log "Finished incremental loading")
            (run-with-idle-timer doom-incremental-idle-timer
                                 nil #'doom-load-packages-incrementally
                                 packages t)
            (setq packages nil)))))))

(defun doom-load-packages-incrementally-h ()
  "Begin incrementally loading packages in `doom-incremental-packages'.

If this is a daemon session, load them all immediately instead."
  (if (daemonp)
      (mapc #'require (cdr doom-incremental-packages))
    (when (integerp doom-incremental-first-idle-timer)
      (run-with-idle-timer doom-incremental-first-idle-timer
                           nil #'doom-load-packages-incrementally
                           (cdr doom-incremental-packages) t))))

(add-hook 'emacs-startup-hook #'doom-load-packages-incrementally-h)


;;
;;; Bootstrap helpers

(defun doom-try-run-hook (hook)
  "Run HOOK (a hook function), but handle errors better, to make debugging
issues easier.

Meant to be used with `run-hook-wrapped'."
  (doom-log "Running doom hook: %s" hook)
  (condition-case e
      (funcall hook)
    ((debug error)
     (signal 'doom-hook-error (list hook e))))
  ;; return nil so `run-hook-wrapped' won't short circuit
  nil)

(defun doom-display-benchmark-h (&optional return-p)
  "Display a benchmark, showing number of packages and modules, and how quickly
they were loaded at startup.

If RETURN-P, return the message as a string instead of displaying it."
  (funcall (if return-p #'format #'message)
           "Doom loaded %d packages across %d modules in %.03fs"
           (- (length load-path) (length doom--initial-load-path))
           (if doom-modules (hash-table-count doom-modules) 0)
           (or doom-init-time
               (setq doom-init-time
                     (float-time (time-subtract (current-time) before-init-time))))))

(defun doom-load-autoloads-file (file)
  "Tries to load FILE (an autoloads file). Return t on success, throws an error
in interactive sessions, nil otherwise (but logs a warning)."
  (condition-case e
      (let (command-switch-alist)
        (load (substring file 0 -3) 'noerror 'nomessage))
    ((debug error)
     (if doom-interactive-mode
         (message "Autoload file warning: %s -> %s" (car e) (error-message-string e))
       (signal 'doom-autoload-error (list (file-name-nondirectory file) e))))))

(defun doom-load-envvars-file (file &optional noerror)
  "Read and set envvars from FILE."
  (if (not (file-readable-p file))
      (unless noerror
        (signal 'file-error (list "Couldn't read envvar file" file)))
    (let (vars)
      (with-temp-buffer
        (insert-file-contents file)
        (while (re-search-forward "\n *\\([^#][^= \n]+\\)=" nil t)
          (save-excursion
            (let ((var (string-trim-left (match-string 1)))
                  (value (buffer-substring-no-properties
                          (point)
                          (1- (or (when (re-search-forward "^\\([^= ]+\\)=" nil t)
                                    (line-beginning-position))
                                  (point-max))))))
              (push (cons var value) vars)
              (setenv var value)))))
      (when vars
        (setq-default
         exec-path (append (parse-colon-path (getenv "PATH"))
                           (list exec-directory))
         shell-file-name (or (getenv "SHELL")
                             shell-file-name))
        (nreverse vars)))))

(defun doom-initialize (&optional force-p)
  "Bootstrap Doom, if it hasn't already (or if FORCE-P is non-nil).

The bootstrap process involves making sure 1) the essential directories exist,
2) the core packages are installed, 3) `doom-autoload-file' and
`doom-package-autoload-file' exist and have been loaded, and 4) Doom's core
files are loaded.

If the cache exists, much of this function isn't run, which substantially
reduces startup time.

The overall load order of Doom is as follows:

  ~/.emacs.d/init.el
  ~/.emacs.d/core/core.el
  ~/.doom.d/init.el
  Module init.el files
  `doom-before-init-modules-hook'
  Module config.el files
  ~/.doom.d/config.el
  `doom-init-modules-hook'
  `after-init-hook'
  `emacs-startup-hook'
  `doom-init-ui-hook'
  `window-setup-hook'

Module load order is determined by your `doom!' block. See `doom-modules-dirs'
for a list of all recognized module trees. Order defines precedence (from most
to least)."
  (when (or force-p (not doom-init-p))
    (setq doom-init-p t)

    ;; Reset as much state as possible, so `doom-initialize' can be treated like
    ;; a reset function. Particularly useful for reloading the config.
    (setq-default exec-path doom--initial-exec-path
                  load-path doom--initial-load-path
                  process-environment doom--initial-process-environment)

    ;; Load shell environment, optionally generated from 'doom env'
    (when (and (or (display-graphic-p)
                   (daemonp))
               (file-exists-p doom-env-file))
      (doom-load-envvars-file doom-env-file))

    (require 'core-modules)
    (let (;; `doom-autoload-file' tells Emacs where to load all its functions
          ;; from. This includes everything in core/autoload/*.el and autoload
          ;; files in enabled modules.
          (core-autoloads-p (doom-load-autoloads-file doom-autoload-file))
          ;; Loads `doom-package-autoload-file', which loads a concatenated
          ;; package autoloads file which caches `load-path', `auto-mode-alist',
          ;; `Info-directory-list', and `doom-disabled-packages'. A big
          ;; reduction in startup time.
          (pkg-autoloads-p
           (when doom-interactive-mode
             (doom-load-autoloads-file doom-package-autoload-file))))

      (if (and core-autoloads-p (not force-p))
          ;; In case we want to use package.el or straight via M-x
          (progn
            (with-eval-after-load 'package
              (require 'core-packages))
            (with-eval-after-load 'straight
              (require 'core-packages)
              (doom-initialize-packages)))

        ;; Eagerly load these libraries because we may be in a session that
        ;; hasn't been fully initialized (e.g. where autoloads files haven't
        ;; been generated or `load-path' populated).
        (mapc (doom-rpartial #'load 'noerror 'nomessage)
              (file-expand-wildcards (concat doom-core-dir "autoload/*.el")))

        ;; Create all our core directories to quell file errors
        (dolist (dir (list doom-local-dir
                           doom-etc-dir
                           doom-cache-dir))
          (unless (file-directory-p dir)
            (make-directory dir 'parents)))

        ;; Ensure the package management system (and straight) are ready for
        ;; action (and all core packages/repos are installed)
        (require 'core-packages)
        (doom-initialize-packages force-p))

      (unless (or (and core-autoloads-p pkg-autoloads-p)
                  force-p
                  (not doom-interactive-mode))
        (unless core-autoloads-p
          (warn "Your Doom core autoloads file is missing"))
        (unless pkg-autoloads-p
          (warn "Your package autoloads file is missing"))
        (signal 'doom-autoload-error "Run `bin/doom refresh' to generate them")))
    t))

(defun doom-initialize-core ()
  "Load Doom's core files for an interactive session."
  (require 'core-keybinds)
  (require 'core-ui)
  (require 'core-projects)
  (require 'core-editor))

(provide 'core)
;;; core.el ends here
