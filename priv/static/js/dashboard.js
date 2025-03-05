import { Application } from "@hotwired/stimulus";
import HotkeyController from "controllers/hotkey";
window.Stimulus = Application.start();
Stimulus.register("hotkey", HotkeyController);
