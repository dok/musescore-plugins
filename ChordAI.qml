import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Controls 2.2
import FileIO 3.0

MuseScore {
      menuPath: "Plugins.ChordAI"
      description: "Generate New Harmonic Movements With AI"
      version: "1.0"

      FileIO {
            id: tempXMLFile
            onError: console.log(msg)
      }

      function generateMusicXML() {
            tempXMLFile.source = tempXMLFile.tempPath() + "//" + "tempExport.xml";
            writeScore(curScore, tempXMLFile.source, "xml");
            return tempXMLFile.read();
      }

      function clearElementType(elementType) {
            var elements = curScore.selection.elements;
            for (var i = 0; i < elements.length; i++) {
                  var el = elements[i]
                  if (el.type === elementType) {
                        removeElement(el);
                  }
            }
      }

      onRun: {
            if (!curScore)
                  Qt.quit();
            
            function getSelectedMeasures(cursor) {
                  cursor.rewind(Cursor.SELECTION_END);
                  var endMeasure = cursor.measure;

                  cursor.rewind(Cursor.SELECTION_START);
                  var measure = cursor.measure;
                  var measures = [];
                  while (measure && !measure.is(endMeasure)) {
                        measures.push(measure);
                        measure = measure.nextMeasure;
                  }
                  measures.push(measure);
                  return measures;
            }

            function getMeasuresBeforeSelection(cursor) {
                  cursor.rewind(Cursor.SELECTION_START);
                  var firstSelMeasure = cursor.measure;
                  cursor.rewind(Cursor.SCORE_START);
                  var measure = cursor.measure;
                  var measures = [];

                  while (measure && !measure.is(firstSelMeasure)) {
                        measures.push(measure);
                        measure = measure.nextMeasure;
                  }
                  return measures;
            }

            function getSelectionRange(cursor) {
                  var measuresBefore = getMeasuresBeforeSelection(cursor);
                  var measuresAfter = getSelectedMeasures(cursor);

                  return [measuresBefore.length + 1, measuresBefore.length + measuresAfter.length]
            }

            function addChords(cursor, chords) {
                  for (var i = 0; i < chords.length; i++) {
                        var el = newElement(Element.HARMONY);
                        el.text = chords[i]
                        cursor.add(el);
                        cursor.nextMeasure();
                  }
            }

            function fetchNewChords(xml, selected, onFinish) {
                  var xhr = new XMLHttpRequest();
                  xhr.onreadystatechange = function() {
                        if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                        } else if(xhr.readyState === XMLHttpRequest.DONE) {
                              console.log(xhr.response);
                              onFinish(JSON.parse(xhr.response));
                        }
                  }
                  var packet = {
                        xml: xml,
                        selection: selected,
                  }
                  xhr.open("POST", "https://music.candidcode.io/chords");
                  xhr.setRequestHeader('Content-Type', 'application/json');
                  xhr.send(JSON.stringify(packet));
            }

            var cursor = curScore.newCursor();
            var selected = getSelectionRange(cursor);

            var xml = generateMusicXML();

            var callback = function(chords) {
                  curScore.startCmd();
                  var sel = curScore.selection;
                  var startTick = sel.startSegment.tick;
                  var endTick = sel.endSegment.tick;
                  var startStaff = sel.startStaff;
                  var endStaff = sel.endStaff;
                  clearElementType(Element.HARMONY)
                  addChords(cursor, chords)
                  curScore.selection.selectRange(startTick, endTick, startStaff, endStaff)
                  curScore.endCmd();
            }
            fetchNewChords(xml, selected, callback);
      }
}
