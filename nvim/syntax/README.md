# Crippling syntax highlighting

Most of the files here are NOT to improve syntax highlighting, but to cripple it.  
We use the modified vim syntax highlighting and disable treesitter highlighting for certain filetypes.  
It leaves primitive stuff (like comments, strings, numbers) highlighted, but removes most of the rest.

## Why?

To prefer semantic highlighting over syntax highlighting. It will make colours when you write semantically correct code. And existing syntax highlighting distracts from that.  

## Why not change treesitter highlighting?

Treesitter highlighting can be changed to be minimised, but sometimes we need them apart from editing code (like markdown code blocks).  
Also their structure from time to time has a breaking change, which would require constant maintenance.

## Affected filetypes

- python (with a plugin)
- javascript
- javascriptreact
- typescript
- typescriptreact

### **NOT** affected filetypes

Below are the exceptions where syntax highlighting is improved (or didn't exist before):

- skhd
