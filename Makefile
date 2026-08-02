# Sandspire — server / local helpers
GODOT ?= $(HOME)/.local/bin/godot
PROJECT ?= .

.PHONY: smoke smoke-economy smoke-build smoke-m1 smoke-power smoke-fog smoke-path smoke-ai smoke-roster smoke-worm smoke-coil smoke-balance smoke-mission smoke-campaign smoke-ux smoke-menu smoke-carryall smoke-all import doctor export-linux templates

doctor:
	@echo "host: $$(hostname)"
	@echo "godot: $$(command -v $(GODOT) || true)"
	@$(GODOT) --version || true
	@echo "templates: $$(ls -d $(HOME)/.local/share/godot/export_templates/4.7.1.stable 2>/dev/null || echo missing)"

import:
	$(GODOT) --headless --path $(PROJECT) --import

templates:
	bash scripts/install_export_templates.sh

export-linux: templates
	mkdir -p build/linux
	$(GODOT) --headless --path $(PROJECT) --export-release "Linux" build/linux/Sandspire.x86_64
	@ls -la build/linux/ || true

smoke:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_boot.gd

smoke-economy:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_economy.gd

smoke-build:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_build.gd

smoke-m1:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_m1.gd

smoke-power:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_power.gd

smoke-fog:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_fog.gd

smoke-path:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_path.gd

smoke-ai:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_ai.gd

smoke-roster:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_roster.gd

smoke-worm:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_worm.gd

smoke-coil:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_coil.gd

smoke-balance:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_balance.gd

smoke-mission:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_mission.gd

smoke-campaign:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_campaign.gd

smoke-ux:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_ux.gd

smoke-menu:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_menu.gd

smoke-carryall:
	$(GODOT) --headless --path $(PROJECT) -s res://scripts/smoke_carryall.gd

smoke-all: smoke smoke-economy smoke-build smoke-m1 smoke-power smoke-fog smoke-path smoke-ai smoke-roster smoke-worm smoke-coil smoke-balance smoke-mission smoke-campaign smoke-ux smoke-menu smoke-carryall
