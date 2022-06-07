# possible values:
# - simulator - to sun on simulator
# - <box name> - box name from ares. to run on emulator or device

# WEBOS_DEVICE=simulator
WEBOS_DEVICE=tv

# Possible values: debug release profile jsdebug
MODE ?= release

# values: html canvaskit
RENDERER ?= canvaskit

#######################################################################
## The rest is not supposed to be changed

MODE := $(strip $(MODE))
WEBOS_DEVICE := $(strip $(WEBOS_DEVICE))

# web generated files
WEB_FILE_NAMES=flutter_service_worker.js favicon.png main.dart.js manifest.json version.json index.html
WEB_FILES=$(addprefix build/web/,$(WEB_FILE_NAMES))

# place webos artifacts in ...
WEBOS_IMM=build/webos.imm
WEBOS_OUT=build/artifacts

# Define sources
SRC_ENTRIES=./lib ./web # ./packages ./fonts ./images  ./android ./ios ./config.json ./Makefile
SRCS=$(shell find $(SRC_ENTRIES) -type f | sort)

# WebOS Sources
APPINFO_JSON=webos/appinfo.json

# Obtain some webos values
APP=$(shell jq -r .id $(APPINFO_JSON))
VER=$(shell jq -r .version $(APPINFO_JSON))

# Package to build
PKG=$(WEBOS_OUT)/$(APP)_$(VER)_all.ipk

TOP_DIR="$(shell pwd)"

# Detect flutter location
FLUTTER_DIR:=$(shell realpath --relative-to . $$(which flutter) | sed -e 's!/bin/flutter$$!!')

# stamping to trace dependencies
STAMP_DIR=build/stamp
STAMP_NAME=$(STAMP_DIR)/$1
STAMP_MAKE=@echo "Stamp $1"; mkdir -p $(STAMP_DIR) && touch $(STAMP_DIR)/$1

ifeq ($(VERBOSE),)
X=@echo "$1...";
else
X=
endif

CHECK_TOOL=command -v $1 > /dev/null || { echo "Command is not available: '$1'"; exit 1;}

# Determine flutter build options
ifeq ($(RENDERER),canvaskit)
FLUTTER_BUILD_OPTS := --web-renderer canvaskit
endif

ifeq ($(RENDERER),asmjs)
FLUTTER_BUILD_OPTS := --web-renderer canvaskit
endif

ifeq ($(RENDERER),html)
FLUTTER_BUILD_OPTS := --web-renderer html
endif

ifeq ($(MODE),jsdebug)
FLUTTER_BUILD_OPTS += --dart-define=Dart2jsOptimization=O0
endif

ifeq ($(MODE),debug)
FLUTTER_BUILD_OPTS += --source-maps --dart-define=dart.developer.timeline=true
endif

ifeq ($(MODE),profile)
FLUTTER_BUILD_OPTS += --profile --source-maps
endif

ifeq ($(MODE),release)
FLUTTER_BUILD_OPTS += --release
endif

# Build rules
.PHONY: build/web $(WEBOS_IMM)
.PHONY: webos-launch webos-install webos-package

# default rule : build webos package only
all: webos-package
run: webos-launch

%.build build/stamp/%: %

.PHONY: rebuild_always
rebuild_always:

$(STAMP_DIR)/web.env: rebuild_always
	@echo "Check build env"

	@$(call CHECK_TOOL,flutter)
	@$(call CHECK_TOOL,dart)
	@$(call CHECK_TOOL,jq)
	@$(call CHECK_TOOL,realpath)
	@$(call CHECK_TOOL,node)

	@$(call CHECK_TOOL,ares-launch)
	@$(call CHECK_TOOL,ares-install)
	@$(call CHECK_TOOL,ares-inspect)
	@$(call CHECK_TOOL,ares-package)

	@mkdir -p $(STAMP_DIR)
	@> $(STAMP_DIR)/web.env.tmp;
	@echo "FLUTTER_BUILD_OPTS=$(FLUTTER_BUILD_OPTS)" >> $(STAMP_DIR)/web.env.tmp;
	@echo "SRCS=$(SRCS)" >> $(STAMP_DIR)/web.env.tmp;
	@echo "REV=$$(git rev-parse HEAD)" >>  $(STAMP_DIR)/web.env.tmp;
	@if ! cmp $(STAMP_DIR)/web.env $(STAMP_DIR)/web.env.tmp > /dev/null 2>&1 ; then \
		rm -f $(STAMP_DIR)/web.env; \
		mv $(STAMP_DIR)/web.env.tmp $(STAMP_DIR)/web.env; \
	fi

$(call STAMP_NAME,flutter-pub): $(STAMP_DIR)/web.env pubspec.yaml pubspec.lock
	flutter pub get
	$(call STAMP_MAKE,flutter-pub)

$(WEB_FILES): $(SRCS) $(STAMP_DIR)/web.env $(call STAMP_NAME,flutter-pub)
	flutter build web $(FLUTTER_BUILD_OPTS)

.PHONY: web
web $(call STAMP_NAME,web): $(WEB_FILES)
	$(call STAMP_MAKE,web)

.PHONY: webos-prepare
webos-prepare $(call STAMP_NAME,webos-prepare): $(call STAMP_NAME,web) webos/appinfo.json $(shell find zbuild/canvaskit.asmjs -type f )
	@rm -rf $(WEBOS_IMM)
	@mkdir -p $(WEBOS_IMM)
	$(call X,copy web data)cp -R build/web/. $(WEBOS_IMM)
ifeq ($(RENDERER),asmjs)
	rm -rf $(WEBOS_IMM)/canvaskit
	cp -r zbuild/canvaskit.asmjs $(WEBOS_IMM)/canvaskit
endif
	$(call X,copy webos data)cp -u webos/appinfo.json $(WEBOS_IMM)
	$(call X,patch index.html)sed -i -e 's!<base href="/">!<base href=".">!' $(WEBOS_IMM)/index.html
	# a.insertRule("    .flt-text-editing::placeholder {\n      opacity: 0;\n    }\n    ",a.cssRules.length)
	sed -i -e 's!^\(.*[.]flt-text-editing::placeholder.*\)$$!// \1!' $(WEBOS_IMM)/main.dart.js

	# webos complains about OpenSans-Regular.ttf. So replace ttf file with woff
	# Do the single value ...
	# jq '(.[] | select(.family == "OpenSans") | .fonts[0].asset ) |= "qwe"' FontManifest.json

	# ... or replace all fonts/<name>.otf to fonts/woff/<name>.woff
	# currently still applied to "OpenSans" family only. Check if we need to replace other files names
	jq '(.[] | select(.family == "OpenSans") | .fonts[0].asset ) |= gsub("/(?<name>[^/]+).(ttf|otf)$$"; "/woff/" + .name + ".woff")' $(WEBOS_IMM)/assets/FontManifest.json > \
		$(WEBOS_IMM)/assets/FontManifest.json.tmp
	mv $(WEBOS_IMM)/assets/FontManifest.json.tmp  $(WEBOS_IMM)/assets/FontManifest.json

	$(call STAMP_MAKE,webos-prepare)

ztools/transform-source-maps/node_modules: ztools/transform-source-maps/package.json ztools/transform-source-maps/package-lock.json
	cd ztools/transform-source-maps && npm i
	touch ztools/transform-source-maps/node_modules

.PHONY: webos-source-maps
webos-source-maps $(call STAMP_NAME,webos-source-maps): $(call STAMP_NAME,webos-prepare) ztools/transform-source-maps/node_modules
ifeq ($(MODE),debug)
	cd $(TOP_DIR)/$(WEBOS_IMM) &&  \
		FLUTTER_DIR=$$(realpath --relative-to . $$(which flutter) | sed -e 's!/bin/flutter$$!!') && \
		$(TOP_DIR)/ztools/transform-source-maps/bin/embed.js \
			-P../$${FLUTTER_DIR}=$${FLUTTER_DIR} \
			-Porg-dartlang-sdk:=$${FLUTTER_DIR}/bin/cache/dart-sdk \
			-P../../../lib=../../lib \
			-P../../../packages=../../packages \
			-Pmain.dart=../../lib/main.dart \
			main.dart.js
endif
	$(call STAMP_MAKE,webos-source-maps)

.PHONY: webos-dir
webos-dir: webos-prepare webos-source-maps

.PHONY: webos-package
webos-package $(call STAMP_NAME,webos-package): $(call STAMP_NAME,webos-prepare)  $(call STAMP_NAME,webos-source-maps)
	$(call X,build webos package)ares-package --no-minify  -o $(WEBOS_OUT) $(WEBOS_IMM)
	$(call STAMP_MAKE,webos-package)

.PHONY: webos-install
webos-install $(call STAMP_NAME,webos-install): $(call STAMP_NAME,webos-package)
ifeq ($(WEBOS_DEVICE),simulator)
	@echo "no need to install on simulator"
else
	$(call X,remove package)ares-install --device $(WEBOS_DEVICE) --remove $(APP) || true
	$(call X,install package)ares-install --device $(WEBOS_DEVICE) $(PKG)
endif
	$(call STAMP_MAKE,webos-install)

.PHONY: webos-launch
webos-launch: webos-install
ifeq ($(WEBOS_DEVICE),simulator)
	@echo "no need to launch on simulator"
else
	ares-launch --device $(WEBOS_DEVICE) --close $(APP) || true
	ares-launch --device $(WEBOS_DEVICE) $(APP)
endif

.PHONY: webos-debug
webos-debug: # webos-launch
ifeq ($(WEBOS_DEVICE),simulator)
	@echo run in simulator. on linux do not forget to rename or link webOS_TV_22_Simulator_1.0.0.AppImage to webOS_TV_22_Simulator_1.0.0.appimage!
	ares-launch -s 22 $(WEBOS_IMM)
else
	ares-inspect --device $(WEBOS_DEVICE) --open $(APP)
endif

.PHONY: webos-debug-new
webos-debug-new: webos-launch webos-debug

clean:
	rm -rf build

# For setups where VPN is available to desktop but TV is not behind VPN.
# Forward AMS connections from tv to Zodiac network
proxy:
	socat tcp-l:9090,fork,reuseaddr tcp:192.168.22.158:9090

# Run flutter debugger in chrome.
# Flutter expects chrome bo be named as `google-chrome`, while on Arch it's `google-chrome-stable`
chrome:
	CHROME_EXECUTABLE=$$(which google-chrome-stable) flutter run --web-renderer html --debug -d chrome
