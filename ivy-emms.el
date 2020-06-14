;;; ivy-emms.el --- Ivy interface to emms tracks     -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Fran Burstall

;; Author: Fran Burstall <fran.burstall@gmail.com>
;; Version: 0.1
;; Package-Requires: ((ivy "0.13.0") (emms "0.0") (emacs "24.1"))
;; Keywords: multimedia
;; URL: https://github.com/franburstall/ivy-emms

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; TODO:
;; - handle playlists and other media?
;; - more actions: show track? Play/pause current? Shuffle?
;; - learn how to package for melpa
;; - write commentary



;;; Code:

(require 'emms-source-file)
(require 'emms-cache)
(require 'ivy)

;;* User options
(defgroup ivy-emms nil
  "Ivy interface to EMMS."
  :group 'emms)

(defcustom ivy-emms-default-action #'ivy-emms-play
  "The default action for the `ivy-emms' command.

Should take a single argument consisting of an item from `ivy-emms-collection'."
  :group 'ivy-emms
  :type 'function)

(defcustom ivy-emms-default-multi-action #'ivy-emms-queue-and-play
  "The default multi-action for the `ivy-emms' action.

Should take a single argument consisting of list of items from `ivy-emms-collection'."
  :group 'ivy-emms
  :type 'function)

;;* Internals
;;** Collection

(defvar ivy-emms-collection nil
  "Collection of emms tracks.

An alist whose cons cells have a search key as car and the path to the track as cdr.")

(defun ivy-emms-simple-make-item (path)
  "Return a `ivy-emms-collection'  item for the track at PATH."
  (let* ((track (gethash path emms-cache-db))
	 (artist (emms-track-get track 'info-artist))
	 (album (emms-track-get track 'info-album))
	 (year (emms-track-get-year track))
	 (tracknum (emms-track-get track 'info-tracknumber))
	 (title (emms-track-get track 'info-title)))
    (cons
     (concat (format "%s-%s" artist album)
	     (when year (format " (%s)" year))
	     ": "
	     (when tracknum (concat tracknum "."))
	     " "
	     title)
     path)))

(defvar ivy-emms-make-item-function #'ivy-emms-simple-make-item
  "Function to make a item for `ivy-emms-collection' from a track.")

;;** History
(defvar ivy-emms-history nil
  "History for `ivy-emms'.")

;;* Actions

;;** Defaults
(defun ivy-emms-play (cand)
  "Play CAND."
  (emms-play-file (cdr cand)))

(defun ivy-emms-queue-and-play (cands)
  "Play first track in CANDS and add the rest to the current playlist."
  (emms-play-file (cdr (car cands)))
  (dolist (cand (cdr cands))
    (emms-add-file (cdr cand))))

;;** Other actions

(defun ivy-emms-add-track (cand)
  "Add CAND to playlist."
  (emms-add-file (cdr cand)))

(defun ivy-emms-play-next (cand)
  "Insert CAND into the current playlist after the current track."
  ;; Should check there is a current playlist
  (with-current-emms-playlist
    (goto-char (if (and emms-playlist-selected-marker
			(marker-position emms-playlist-selected-marker))
		   emms-playlist-selected-marker
		 (point-min)))
    (condition-case nil
	(emms-playlist-next)
      (error
       (goto-char (point-max))))
    (emms-insert-file (cdr cand))))

(defun ivy-emms-play-next-multi (cands)
  "Insert CANDS into the current playlist after the current track."
  (mapc #'ivy-emms-play-next (nreverse cands)))

(ivy-add-actions 'ivy-emms
		 '(("a" ivy-emms-add-track "Add track")
		   ("i" ivy-emms-play-next "Play track next" ivy-emms-play-next-multi)))

;;* Entry point
;;;###autoload
(defun ivy-emms (arg)
  "Search for EMMS tracks using ivy.

With a prefix ARG, invalidate the cache and reread the list of tracks."
  (interactive "P")
  (unless (and ivy-emms-collection (not arg))
    (setq ivy-emms-collection
	  (mapcar (lambda (k) (funcall ivy-emms-make-item-function k))
		  (hash-table-keys emms-cache-db))))
  (let ((current-prefix-arg nil))
    (ivy-read "Track: " ivy-emms-collection
	      :action ivy-emms-default-action
	      :caller 'ivy-emms
	      :history 'ivy-emms-history
	      :multi-action ivy-emms-default-multi-action)))

(provide 'ivy-emms)
;;; ivy-emms.el ends here
