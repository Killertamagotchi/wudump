#---------------------------------------------------------------------------------
# Clear the implicit built in rules
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITPPC)),)
$(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>devkitPPC")
endif
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitPRO")
endif
export PATH			:=	$(DEVKITPPC)/bin:$(PORTLIBS)/bin:$(PATH)
export LIBOGC_INC	:=	$(DEVKITPRO)/libogc/include
export LIBOGC_LIB	:=	$(DEVKITPRO)/libogc/lib/wii
export PORTLIBS		:=	$(DEVKITPRO)/portlibs/ppc

PREFIX	:=	powerpc-eabi-

export AS	:=	$(PREFIX)as
export CC	:=	$(PREFIX)gcc
export CXX	:=	$(PREFIX)g++
export AR	:=	$(PREFIX)ar
export OBJCOPY	:=	$(PREFIX)objcopy

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# INCLUDES is a list of directories containing extra header files
#---------------------------------------------------------------------------------
TARGET		:=	wud2sd
BUILD		:=	build
BUILD_DBG	:=	$(TARGET)_dbg
SOURCES		:=	src \
				src/dynamic_libs \
				src/fs \
				src/system \
				src/utils
DATA		:=  

INCLUDES	:=  src payload

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
CFLAGS	:=  -std=gnu11 -mrvl -mcpu=750 -meabi -mhard-float -ffast-math \
		    -O3 -Wall -Wextra -Wno-unused-parameter -Wno-strict-aliasing $(INCLUDE)
CXXFLAGS := -std=gnu++11 -mrvl -mcpu=750 -meabi -mhard-float -ffast-math \
		    -O3 -Wall -Wextra -Wno-unused-parameter -Wno-strict-aliasing $(INCLUDE)
ASFLAGS	:= -mregnames
LDFLAGS	:= -nostartfiles -Wl,-Map,$(notdir $@).map,-wrap,malloc,-wrap,free,-wrap,memalign,-wrap,calloc,-wrap,realloc,-wrap,malloc_usable_size,-wrap,_malloc_r,-wrap,_free_r,-wrap,_realloc_r,-wrap,_calloc_r,-wrap,_memalign_r,-wrap,_malloc_usable_size_r,-wrap,valloc,-wrap,_valloc_r,-wrap,_pvalloc_r,--gc-sections

#---------------------------------------------------------------------------------
Q := @
MAKEFLAGS += --no-print-directory
#---------------------------------------------------------------------------------
# any extra libraries we wish to link with the project
#---------------------------------------------------------------------------------
LIBS	:= -lfat -liosuhax 

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:=	$(CURDIR)	\
			$(DEVKITPPC)/lib

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------
export PROJECTDIR := $(CURDIR)
export OUTPUT	:=	$(CURDIR)/$(TARGETDIR)/$(TARGET)
export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
					$(foreach dir,$(DATA),$(CURDIR)/$(dir))
export DEPSDIR	:=	$(CURDIR)/$(BUILD)

#---------------------------------------------------------------------------------
# automatically build a list of object files for our project
#---------------------------------------------------------------------------------
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
sFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.S)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
	export LD	:=	$(CC)
else
	export LD	:=	$(CXX)
endif

export OFILES	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) \
					$(sFILES:.s=.o) $(SFILES:.S=.o) \
					$(PNGFILES:.png=.png.o) $(addsuffix .o,$(BINFILES))

#---------------------------------------------------------------------------------
# build a list of include paths
#---------------------------------------------------------------------------------
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
					$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD) -I$(LIBOGC_INC) \
					-I$(PORTLIBS)/include -I$(PORTLIBS)/include/freetype2

#---------------------------------------------------------------------------------
# build a list of library paths
#---------------------------------------------------------------------------------
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib) \
					-L$(LIBOGC_LIB) -L$(PORTLIBS)/lib

export OUTPUT	:=	$(CURDIR)/$(TARGET)
.PHONY: $(BUILD) clean install

#---------------------------------------------------------------------------------
$(BUILD): $(CURDIR)/payload/arm_kernel_bin.h
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

$(CURDIR)/payload/arm_kernel_bin.h:  $(CURDIR)/payload/wupserver_bin.h $(CURDIR)/payload/arm_user_bin.h $(CURDIR)/payload/odmhook_bin.h
	@$(MAKE) --no-print-directory -C $(CURDIR)/arm_kernel -f  $(CURDIR)/arm_kernel/Makefile
	@-mkdir -p $(CURDIR)/payload
	@cp -p $(CURDIR)/arm_kernel/arm_kernel_bin.h $@

$(CURDIR)/payload/wupserver_bin.h:
	@$(MAKE) --no-print-directory -C $(CURDIR)/wupserver -f  $(CURDIR)/wupserver/Makefile
	@-mkdir -p $(CURDIR)/payload
	@cp -p $(CURDIR)/wupserver/wupserver_bin.h $@

$(CURDIR)/payload/odmhook_bin.h:
	@$(MAKE) --no-print-directory -C $(CURDIR)/odmhook -f  $(CURDIR)/odmhook/Makefile
	@-mkdir -p $(CURDIR)/payload
	@cp -p $(CURDIR)/odmhook/odmhook_bin.h $@

$(CURDIR)/payload/arm_user_bin.h:
	@$(MAKE) --no-print-directory -C $(CURDIR)/arm_user -f  $(CURDIR)/arm_user/Makefile
	@-mkdir -p $(CURDIR)/payload
	@cp -p $(CURDIR)/arm_user/arm_user_bin.h $@

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(OUTPUT).elf $(OUTPUT).bin $(BUILD_DBG).elf $(CURDIR)/payload
	@$(MAKE) --no-print-directory -C $(CURDIR)/arm_user -f  $(CURDIR)/arm_user/Makefile clean
	@$(MAKE) --no-print-directory -C $(CURDIR)/wupserver -f  $(CURDIR)/wupserver/Makefile clean
	@$(MAKE) --no-print-directory -C $(CURDIR)/odmhook -f  $(CURDIR)/odmhook/Makefile clean
	@$(MAKE) --no-print-directory -C $(CURDIR)/arm_kernel -f  $(CURDIR)/arm_kernel/Makefile clean


#---------------------------------------------------------------------------------
else

DEPENDS	:=	$(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
$(OUTPUT).elf:  $(OFILES)

#---------------------------------------------------------------------------------
# This rule links in binary data with the .jpg extension
#---------------------------------------------------------------------------------
%.elf: link.ld $(OFILES)
	@echo "linking ... $(TARGET).elf"
	$(Q)$(LD) -n -T $^ $(LDFLAGS) -o ../$(BUILD_DBG).elf  $(LIBPATHS) $(LIBS)
	$(Q)$(OBJCOPY) -S -R .comment -R .gnu.attributes ../$(BUILD_DBG).elf $@

../data/loader.bin:
	$(MAKE) -C ../loader clean
	$(MAKE) -C ../loader
#---------------------------------------------------------------------------------
%.a:
#---------------------------------------------------------------------------------
	@echo $(notdir $@)
	@rm -f $@
	@$(AR) -rc $@ $^

#---------------------------------------------------------------------------------
%.o: %.cpp
	@echo $(notdir $<)
	@$(CXX) -MMD -MP -MF $(DEPSDIR)/$*.d $(CXXFLAGS) -c $< -o $@ $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.c
	@echo $(notdir $<)
	@$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d $(CFLAGS) -c $< -o $@ $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.S
	@echo $(notdir $<)
	@$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d -x assembler-with-cpp $(ASFLAGS) -c $< -o $@ $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.png.o : %.png
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.jpg.o : %.jpg
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.ttf.o : %.ttf
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.bin.o : %.bin
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.wav.o : %.wav
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.mp3.o : %.mp3
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

#---------------------------------------------------------------------------------
%.ogg.o : %.ogg
	@echo $(notdir $<)
	@bin2s -a 32 $< | $(AS) -o $(@)

-include $(DEPENDS)

#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------
