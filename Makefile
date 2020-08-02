
include config.mk

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

dir-y-tree :=
src-y-tree := 
dir-y :=
src-y := 

$(eval $(call add-sources-descend,sources))

.PHONY: all
all:
	$(info $$dir-y-tree $(dir-y-tree))
	$(info $$src-y-tree $(src-y-tree))

	
