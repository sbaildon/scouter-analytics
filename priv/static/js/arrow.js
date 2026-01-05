import { tableFromIPC, RowIndex } from "apache-arrow";

const csrfToken = document
	.querySelector("meta[name='csrf-token']")
	.getAttribute("content");
const arrow = window.liveSocket.channel("arrow", { _csrf_token: csrfToken });

let groupIds;
arrow
	.join()
	.receive("ok", (resp) => {
		groupIds = resp;
	})
	.receive("error", (resp) => {
		console.log("Unable to join");
	});

arrow.on("empty", () => {
	for (const group_id in groupIds) {
		document.getElementById(`group_${group_id}`)?.replaceChildren();
	}
});

arrow.on("receive", (payload) => {
	const group_id = new DataView(payload).getUint32(0, false); // Get first 32 bits, the group_id

	const arrow = payload.slice(4); // Skip first 4 bytes (32 bits) to get remaining data
	const table = tableFromIPC(arrow, { useProxy: true });

	const columns = table.toColumns();

	const fragment = document.createDocumentFragment();
	const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");

	const height = parseFloat(getComputedStyle(document.body).lineHeight);

	svg.setAttribute("class", "w-full");
	svg.setAttribute("font-size", "14");
	svg.setAttribute("height", `${height * table.numRows}`);

	fragment.appendChild(svg);

	for (const row of table) {
		const bg = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"rect",
		);
		bg.setAttribute("y", `${row[RowIndex] * height}`);
		bg.setAttribute("width", "100%");
		bg.setAttribute("height", height);
		bg.setAttribute("fill", "transparent");

		const bar = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"rect",
		);

		bar.setAttribute("y", `${row[RowIndex] * height}`);
		bar.setAttribute(
			"width",
			`${Math.max(0.2, (row.count / row.max) * 100)}%`,
		);
		bar.setAttribute("height", height);
		bar.setAttribute("fill", `oklch(84.1% 0.238 128.85 / 40%)`); // --color-lime-400

		const valueLabel = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"text",
		);
		valueLabel.setAttribute("x", "1ch");
		valueLabel.setAttribute("y", `${row[RowIndex]}.5lh`);
		valueLabel.setAttribute("dominant-baseline", "central");
		valueLabel.setAttribute("fill", "black");
		valueLabel.textContent = row.present || row.value || "<Unknown>";

		const countLabel = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"text",
		);
		countLabel.setAttribute("x", "100%");
		countLabel.setAttribute("dx", "-1ch");
		countLabel.setAttribute("y", `${row[RowIndex]}.5lh`);
		countLabel.setAttribute("dominant-baseline", "central");
		countLabel.setAttribute("fill", "black");
		countLabel.setAttribute("text-anchor", "end");
		countLabel.textContent = row.count;

		const foreignObject = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"foreignObject",
		);

		foreignObject.setAttribute("y", `${row[RowIndex]}lh`);
		foreignObject.setAttribute("width", "100%");
		foreignObject.setAttribute("height", height);

		const group = document.createElementNS(
			"http://www.w3.org/2000/svg",
			"g",
		);
		group.setAttribute("phx-click", "filter");
		group.setAttribute("phx-value-value", row.value || "");
		group.setAttribute("phx-value-group", groupIds[group_id]);
		group.appendChild(bg);
		group.appendChild(bar);
		group.appendChild(valueLabel);
		group.appendChild(countLabel);
		// group.appendChild(foreignObject);
		svg.appendChild(group);
	}

	document.getElementById(`group_${group_id}`).replaceChildren(fragment);
});
