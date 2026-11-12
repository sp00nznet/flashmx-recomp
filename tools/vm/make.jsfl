// Flash MX 2004 harness: build a small document, save it as .fla and export .swf
var out = "file:///C|/fl/out/";
var doc = fl.createDocument();
doc.width = 320; doc.height = 240; doc.frameRate = 12;
doc.backgroundColor = "#336699";
doc.addNewRectangle({left: 20, top: 20, right: 140, bottom: 100}, 0);
doc.addNewOval({left: 160, top: 40, right: 300, bottom: 200});
doc.addNewLine({x: 10, y: 230}, {x: 310, y: 120});
doc.addNewText({left: 20, top: 150, right: 150, bottom: 180});
doc.setTextString("Hello, recomp");
doc.selectNone();
doc.getTimeline().insertBlankKeyframe(5);
doc.addNewRectangle({left: 100, top: 100, right: 220, bottom: 140}, 10);
doc.getTimeline().layers[0].frames[0].actionScript = "trace('frame 1');";
fl.saveDocument(doc, out + "harness.fla");
doc.exportSWF(out + "harness.swf", true);
FLfile.write(out + "done.txt", "ok");
fl.closeDocument(doc, false);
fl.quit(false);
