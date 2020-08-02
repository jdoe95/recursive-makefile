## A Project Makefile Similar to the KBuild System

The Linux KBuild system can discover and isolate the source files that need be built into the final binary from those that are not needed from a single `.config` file. This project is another implementation of this mechanism that illustrates my understanding of how it **may** work.

## Sample Project Structure
```
.
├── config.mk
├── Makefile
└── sources
    ├── Makefile
    ├── newsample
    │   └── Makefile
    └── sample
        └── Makefile

3 directories, 5 files
```

The project root directory contains the config file, `config.mk`, a `sources` folder containing project source code, and `Makefile`, the default file read by `GNU Make` when running command `make all`.

`config.mk` contains variables that specify the project configuration in the form of Makefile variable assignment syntax. The value of the variables can be `y` or otherwise, where `y` means to build the source code.

Snapshot of `config.mk`

```Makefile
CONFIG_SAMPLE := y
CONFIG_NEWSAMPLE := n
```

Each source code subdirectory in `sources` contains a Makefile, which specifies the sources to build under different configurations in the form of Makefile variable assignment syntax. These Makefiles, along with the project configuration `config.mk` will be recursively included by the project Makefile using a mechanism introduced in the next section.

Snapshot of a Makefile in the source folder

```Makefile
dir-$(CONFIG_SAMPLE) += sample 
dir-$(CONDIG_NEWSAMPLE) += newsample
src-y += sources1.c sources2.c
```

GNU Make allows a variable to be used as the name of another variable, referred to as [Computed Variable Names](https://www.gnu.org/software/make/manual/html_node/Computed-Names.html#Computed-Names). For example, the variable name `dir-$(CONFIG_SAMPLE)` contains the value of the variable `CONFIG_SAMPLE`. When the value of `CONFIG_SAMPLE` is `y` the name of the variable will evaluate to `dir-y` and when the value is `n`, `dir-n`, and so on. Most importantly, the statements

```Makefile
obj-$(CONFIG_SAMPLE) += sample
src-$(CONFIG_SAMPLE) += sample1.c
```

will evaluate to 

```Makefile
dir-y += sample
src-y += sample1.c
```

if the value of `CONFIG_SAMPLE` is `y`, and 

```Makefile
dir-n += sample
src-n += sample1.c
```

if the value is `n`.

`src-y` tells the project Makefile which sources under the same directory need to be built, while `dir-y` tells the project Makefile which subdirectories to descend into to include more Makefiles.

When the project Makefile includes the Makefile in each source subdirectory, the statements in the source directory Makefiles updates variables of the project Makefile. The project Makefile does not process other variables such as `dir-n` and `src-n`, and only contains statements referencing `dir-y` and `src-y`, effectively ignoring files and directories not included in the build.

## Makefile Discovery Mechanism
The following piece of recursive function in the form of a variable is key to the the discovery mechanism. 

_Note: It didn't work when I added the indentations._

```Makefile
define add-sources-descend =
dir-y := 
src-y := 
include $(1)/Makefile
dir-y-tree += $(1)
src-y-tree += $$(addprefix $(1)/,$$(src-y))
subdir-y := $$(addprefix $(1)/,$$(dir-y))
$$(foreach d,$$(subdir-y),$$(eval $$(call $(0),$$(d))))
dir-y := 
src-y := 
endef
```
The block defines a multi-line variable `add-sources-descend` containing text in the form of Makefile syntax. The value of this variable is used as a template to generate more Makefile statements. When the GNU Make built-in function `call` is used on this variable, the `$(0)`, `$(1)`, ... placeholders in the text will be replaced by parameters passed to `call`, while `$$` in the text will be replaced by a single `$`. For example,

```Makefile
$(call add-sources-descend,sources)
```

evaluates into the following piece of text

```Makefile
dir-y := 
src-y := 
include sources/Makefile
dir-y-tree += sources
src-y-tree += $(addprefix sources/,$(src-y))
subdir-y := $(addprefix sources/,$(dir-y))
$(foreach d,$(subdir-y),$(eval $(call add-sources-descend,$(d))))
dir-y := 
src-y := 
```

Note that the `$(0)` placeholder is replaced by `add-sources-descend` and the `$(1)` placeholder is replaced by the first paramter passed to `call`, `sources`.

As can be seen, if the piece of text in the form of Makefile syntax is to be executed by GNU Make as statements, it does the following

1. Clears variables `dir-y` and `src-y`
1. Includes the Makefile under the directory it is invoked on (in this case, `sources`), which will contain statements adding filenames to `dir-y` and `src-y` variables.
1. Adds the directory it is invoked on to the directory tree.
1. Appends the path of the directory it is invoked on to the source files discovered in the directory Makefile, and add them the source file tree.
1. Invokes itself for each subdirectory discovered in the directory Makefile.
1. Clears variables `dir-y` and `src-y`.

This piece of recursive script will effectively invoke itself in each subdirectory specified in the assignment statements in the directory Makefile, thus discovering all the source files needed to complete the build.

Importantly, the result of `call` function is only a piece of text, and will not be executed by make unless the `eval` function is invoked on it. The `eval` function asks Make to execute a piece of text as regular statements. This is the case in the `add-sources-descend` function. In addition, the following statements are used to launch the first instance of the piece of script on the top source directory.

```Makefile
dir-y-tree :=
src-y-tree := 
dir-y :=
src-y := 

$(eval $(call add-sources-descend,sources))
```

As soon as the `eval` statement is executed, variable `src-y-tree` will contain the sources needed building under the configuration specified by `config.mk`,and `dir-y-tree`, the directory structure. The variables containing file paths can then be passed to the compiler to generate object files.

