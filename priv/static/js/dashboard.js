import { Application } from "@hotwired/stimulus";
import HotkeyController from "controllers/hotkey";
import ServiceController from "controllers/service";
window.Stimulus = Application.start();
Stimulus.register("hotkey", HotkeyController);
Stimulus.register("service", ServiceController);
