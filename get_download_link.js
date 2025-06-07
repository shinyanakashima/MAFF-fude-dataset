const ctx = document.getElementById("dl-ok-list-span");
const rows = [["text", "url", "filename"]];
const filteredNodes = Array.from(ctx.childNodes).filter(
  node => !(node.nodeType === Node.ELEMENT_NODE && node.tagName === "BR")
);

for (let i = 0; i < filteredNodes.length - 1; i++) {
  const textNode = filteredNodes[i];
  const linkNode = filteredNodes[i + 1];

  // テキストノード → aタグ のペアで処理
  if (textNode.nodeType === Node.TEXT_NODE &&
      linkNode.nodeType === Node.ELEMENT_NODE &&
      linkNode.tagName === "A") {

    const text = textNode.textContent.trim();
    const url = linkNode.getAttribute("href") || "";
    const filename = linkNode.getAttribute("download") || "";

    rows.push([text, url, filename]);
    i++; // 次のループではスキップ済みのaタグの次から
  }
}

// CSV出力
const csv = rows.map(row =>
  row.map(field => `"${field.replace(/"/g, '""')}"`).join(",")
).join("\n");

const blob = new Blob([csv], { type: "text/csv" });
const a = document.createElement("a");
a.href = URL.createObjectURL(blob);
a.download = "output.csv";
a.click();


