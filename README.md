helm-cscope
===========

helm frontend for cscope.

Dependencies:
===========

helm and xcscope.el

Installation:
=============

Add dir to load path where helm-cscope.el is located and add a require statement to your emacs config file:

```elisp
(require 'helm-cscope)
```

Usage:
======

Provided 2 sets of functions similar to cscope (xcscope.el) with prefix helm-. E.g. helm-cscope-find-this-symbol and helm-cscope-find-this-symbol-no-prompt

Customization:
==============

helm-cscope-display: function that takes (file function-name line-number line) and return a string for helm-cscope to show the result
