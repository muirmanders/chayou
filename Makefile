#
# Makefile
#
#
#

###########################

# You need to edit these values.

DICT_NAME		=	"查友"
DICT_SRC_PATH		=	MyDictionary.xml
CSS_PATH		=	MyDictionary.css
PLIST_PATH		=	MyInfo.plist

CEDICT_FILE		=   ~/Downloads/cedict_1_0_ts_utf-8_mdbg.txt

DICT_BUILD_OPTS		=
# Suppress adding supplementary key.
# DICT_BUILD_OPTS		=	-s 0	# Suppress adding supplementary key.

###########################

# The DICT_BUILD_TOOL_DIR value is used also in "build_dict.sh" script.
# You need to set it when you invoke the script directly.

DICT_BUILD_TOOL_DIR	=	"/Developer/Extras/Dictionary Development Kit"
DICT_BUILD_TOOL_BIN	=	"$(DICT_BUILD_TOOL_DIR)/bin"

###########################

DICT_DEV_KIT_OBJ_DIR	=	./objects
export	DICT_DEV_KIT_OBJ_DIR

DESTINATION_FOLDER	=	/Library/Dictionaries
RM			=	/bin/rm
PERL		= 	/usr/bin/perl

###########################

all:
	$(PERL) build_dict.pl $(CEDICT_FILE)
	"$(DICT_BUILD_TOOL_BIN)/build_dict.sh" $(DICT_BUILD_OPTS) $(DICT_NAME) $(DICT_SRC_PATH) $(CSS_PATH) $(PLIST_PATH)
	echo "Done."


install:
	echo "Installing into $(DESTINATION_FOLDER)".
	mkdir -p $(DESTINATION_FOLDER)
	sudo ditto --noextattr --norsrc $(DICT_DEV_KIT_OBJ_DIR)/$(DICT_NAME).dictionary  $(DESTINATION_FOLDER)/$(DICT_NAME).dictionary
	sudo touch $(DESTINATION_FOLDER)
	sudo chown -R root:wheel $(DESTINATION_FOLDER)/$(DICT_NAME).dictionary
	echo "Done."
	echo "To test the new dictionary, try Dictionary.app."

clean:
	$(RM) -rf $(DICT_DEV_KIT_OBJ_DIR)
