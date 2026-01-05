import { Application } from "@hotwired/stimulus";
import HotkeyController from "controllers/hotkey";
import ServiceController from "controllers/service";
window.Stimulus = Application.start();
Stimulus.register("hotkey", HotkeyController);
Stimulus.register("service", ServiceController);

import topbar from "topbar";

import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

const csrfToken = document
	.querySelector("meta[name='csrf-token']")
	.getAttribute("content");
const path = document
	.querySelector("meta[name='path']")
	.getAttribute("content");
const liveSocket = new LiveSocket(`/_app/analytics/live`, Socket, {
	longPollFallbackMs: 2500,
	params: {
		_csrf_token: csrfToken,
		time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
		query: new URL(window.location).searchParams.toString(),
	},
});

// this is a very questionable hack
// --------------------------------
// hypothetically if a  a reverse proxy is to handle the path
// /tenant/:tenant_id/analytics but strip it to the bare root '/', and
// foward it to this phoenix application, nothing will work because the
// router does not define a `live` macro at the unstripped route available at
// window.location.href (eg `live "/tenant/:tenant_id/analytics", StatsLive,
// :index`), only the stripped route.
//
// the LiveSocket constructor, as of
// phoenix_live_view#ea400660b8d75b641021a047eb2881cbca4581c4
// assets/js/phoenix_live_view/live_socket.js:149 puts the unstripped path
// from window.location.href into the socket
//
// then the liveview socket tries to connect, but logic in
// phoenix_live_view#ea400660b8d75b641021a047eb2881cbca4581c4
// lib/phoenix_live_view/channel.ex:1053 checks the
// javascript socket.href via a series of elixir calls
// landing at phoenix#21ee2610ab20557a9ad1fd8f7599f5b5fe5d9b5d
// lib/phoenix/router.ex:1267
//
// if the socket.href does not have live path associated in the router. it
// will break so, because "/" does not exist in the router, and requests
// may come from a different path via reverse proxy, we forcefully override
// it to be the root path
const location = new URL(window.location);
location.pathname = "/";
liveSocket.href = location.href;

window.addEventListener("phx:query", (e) => {
	const params = new URLSearchParams();
	for (const [key, values] of new Map(Object.entries(e.detail))) {
		if (Array.isArray(values)) {
			for (const value of values) {
				params.append(key, value);
			}
		} else {
			params.append(key, values);
		}
	}

	const url = new URL(window.location);
	url.search = params.toString();

	history.pushState(null, "", url);
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
