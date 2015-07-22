# markdown-hub.el

markdown-hub.el is a [Markdown Hub](https://github.com/papaeye/markdown-hub) publisher for Emacs.  It uses Markdown Hub as a Docker container.

markdown-hub.el and Markdown Hub are based on [syohex/emacs-realtime-markdown-viewer](https://github.com/syohex/emacs-realtime-markdown-viewer).

## Requirements

* Docker
* Emacs 24.4 or later
* [websocket.el](http://elpa.gnu.org/packages/websocket.html) 1.4 or later

## Install

1. Put `markdown-hub.el` somewhere in your `load-path`.
2. Add the following code into your .emacs:

    ```el
    (autoload 'markdown-hub-mode "markdown-hub" nil t)
    (autoload 'markdown-hub-browse "markdown-hub" nil t)
    ```

## Usage

(Pull the Docker image of Markdown Hub in advance: `docker pull papaeye/markdown-hub`)

1. Open a Markdown file.
2. Run `M-x markdown-hub-browse` to open the Markdown Hub preview page.  It starts the Docker container of Markdown Hub if it is not running.
3. Run `M-x markdown-hub-mode` to enable Markdown-Hub mode in the Markdown buffer.  Now you can experience live Markdown preview in the Markdown Hub preview page.

To use with boot2docker, add the following code into your .emacs:

```el
(setq markdown-hub-hostname 'boot2docker)
```
