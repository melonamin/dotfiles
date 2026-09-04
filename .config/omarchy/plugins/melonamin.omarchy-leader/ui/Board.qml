import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property var model: ({ path: [], choices: [], typedKeys: [], phase: "active", errorMessage: "", statusMessage: "" })
  property var theme: ({
    panelPadding: 20, radius: 12, mediumGap: 14, smallGap: 8,
    background: "#101315", foreground: "#cacccc", border: "#707880",
    muted: "#707880", accent: "#cacccc", urgent: "#a55555",
    selectedBackground: "#202426", selectedBorder: "#303638",
    fontFamily: "sans-serif", titleSize: 20, bodySize: 14, captionSize: 12
  })

  implicitWidth: 680
  implicitHeight: Math.min(620, cardColumn.implicitHeight + theme.panelPadding * 2)

  function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: Math.max(10, root.theme.radius)
    color: root.theme.background
    border.color: root.model.phase === "error" ? root.theme.urgent : root.theme.border
    border.width: 1

    ColumnLayout {
      id: cardColumn
      anchors.fill: parent
      anchors.margins: root.theme.panelPadding
      spacing: root.theme.mediumGap

      RowLayout {
        Layout.fillWidth: true
        spacing: root.theme.smallGap

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 3

          Text {
            Layout.fillWidth: true
            text: {
              var labels = ["Home"]
              for (var i = 0; i < root.model.path.length; i++) labels.push(root.model.path[i].label)
              return labels.join("  ›  ")
            }
            color: root.theme.muted
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.captionSize
            font.capitalization: Font.AllUppercase
            elide: Text.ElideMiddle
          }

          Text {
            Layout.fillWidth: true
            text: root.model.path.length > 0 ? root.model.path[root.model.path.length - 1].label : "Leader"
            color: root.theme.foreground
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.titleSize
            font.weight: Font.DemiBold
          }
        }

        Text {
          text: root.model.typedKeys.join(" ") || "·"
          color: root.theme.accent
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.titleSize
          font.weight: Font.Bold
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: messageText.implicitHeight + root.theme.smallGap * 2
        visible: root.model.errorMessage !== "" || root.model.statusMessage !== ""
        radius: Math.max(6, root.theme.radius * 0.7)
        color: root.model.phase === "error"
          ? root.alpha(root.theme.urgent, 0.14)
          : root.theme.selectedBackground

        Text {
          id: messageText
          anchors.fill: parent
          anchors.margins: root.theme.smallGap
          text: root.model.errorMessage || root.model.statusMessage
          color: root.model.phase === "error" ? root.theme.urgent : root.theme.foreground
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.bodySize
          wrapMode: Text.Wrap
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: root.model.choices.length === 1 ? 1 : 2
        columnSpacing: root.theme.smallGap
        rowSpacing: root.theme.smallGap

        Repeater {
          model: root.model.choices

          delegate: Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 62
            radius: Math.max(7, root.theme.radius * 0.75)
            color: root.theme.selectedBackground
            border.color: root.theme.selectedBorder
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 11

              Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 8
                color: root.alpha(root.theme.accent, 0.15)
                border.color: root.alpha(root.theme.accent, 0.4)
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: modelData.key
                  color: root.theme.accent
                  font.family: root.theme.fontFamily
                  font.pixelSize: root.theme.bodySize
                  font.weight: Font.Bold
                }
              }

              Text {
                visible: modelData.icon !== ""
                text: modelData.icon
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.titleSize
              }

              Text {
                Layout.fillWidth: true
                text: modelData.label
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.bodySize
                font.weight: Font.Medium
                elide: Text.ElideRight
              }

              Text {
                text: modelData.action ? "" : "›"
                color: root.theme.muted
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.titleSize
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: "backspace  back    ?  reveal"
          color: root.theme.muted
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.captionSize
        }

        Text {
          text: "esc  close"
          color: root.theme.muted
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.captionSize
        }
      }
    }
  }
}
