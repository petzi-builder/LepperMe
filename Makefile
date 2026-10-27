APP_NAME := LepperMe
APP      := build/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications

.PHONY: run build install uninstall zip icon preview clean

run:
	./run.sh

build:
	./run.sh --no-open

install: build
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	@echo "Installiert nach $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	pkill -x "$(APP_NAME)" 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

# ZIP for GitHub Releases
zip: build
	cd build && ditto -c -k --keepParent "$(APP_NAME).app" "$(APP_NAME).zip"
	@echo "build/$(APP_NAME).zip"

# Restarts the app and shows an overlay right away: make preview KIND=eyes|posture|rest
# (`open` alone would just activate a running instance and drop the arguments.)
KIND ?= rest
preview:
	@pkill -x "$(APP_NAME)" 2>/dev/null; for i in $$(seq 1 50); do pgrep -x "$(APP_NAME)" >/dev/null || break; sleep 0.1; done; sleep 0.5
	open "$(APP)" --args --preview $(KIND)

# Regenerates Resources/AppIcon.icns from the revel8 "8" (needs one build first).
icon: build
	rm -rf build/AppIcon.iconset && mkdir -p build/AppIcon.iconset
	"$(APP)/Contents/MacOS/$(APP_NAME)" --render-icon build/icon-1024.png
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s build/icon-1024.png --out build/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		sips -z $$((s*2)) $$((s*2)) build/icon-1024.png --out build/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "Resources/AppIcon.icns aktualisiert. Mit make build ins Bundle übernehmen."

clean:
	rm -rf .build build "$(HOME)/Library/Caches/$(APP_NAME)"
