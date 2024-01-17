# https://github.com/leafo/magick

luarocks magick v1.6.0 clone. `3rd/image.nvim` dependency. You also need ImageMagick v7 shared library and headers.

The script looks for the appropriate shared library using `pkg-config` but it wasn't able to find the locally installed ones.  
So I modified the wand/lib.lua as follows:

```lua
  local proc = io.popen(
    'PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:/home/linuxbrew/.linuxbrew/lib/pkgconfig:$PKG_CONFIG_PATH" pkg-config --cflags --libs MagickWand',
    "r"
  )

  --------------------

  local prefixes = {
    "/usr/include/ImageMagick",
    "/usr/local/include/ImageMagick",
    vim.fn.expand "$HOME" .. "/.local/include/ImageMagick",
    "/home/linuxbrew/.linuxbrew/include/ImageMagick",
    -- ...
  }
```
