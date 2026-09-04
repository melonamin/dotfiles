import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property var model: ({ path: [], choices: [], typedKeys: [], phase: "active", errorMessage: "", statusMessage: "" })
  property var theme: ({
    panelPadding: 20, radius: 12, smallGap: 8, background: "#101315",
    foreground: "#cacccc", border: "#707880", muted: "#707880",
    accent: "#cacccc", urgent: "#a55555", selectedBorder: "#303638",
    fontFamily: "sans-serif", bodySize: 14, captionSize: 12
  })

  implicitWidth: 360
  implicitHeight: Math.min(500, cornerColumn.implicitHeight + theme.panelPadding * 2)

  function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }

  Rectangle {
    anchors.fill: parent
    radius: Math.max(10, root.theme.radius)
    color: root.theme.background
    border.color: root.model.phase === "error" ? root.theme.urgent : root.theme.border
    border.width: 1

    ColumnLayout {
      id: cornerColumn
      anchors.fill: parent
      anchors.margins: root.theme.panelPadding
      spacing: root.theme.smallGap

      RowLayout {
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: {
            var labels = []
            for (var i = 0; i < root.model.path.length; i++) labels.push(root.model.path[i].label)
            return labels.length ? labels.join(" › ") : "Leader"
          }
          color: root.theme.foreground
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.bodySize
          font.weight: Font.DemiBold
          elide: Text.ElideMiddle
        }

        Text {
          text: root.model.typedKeys.join("") || "·"
          color: root.theme.accent
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.bodySize
          font.weight: Font.Bold
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.alpha(root.theme.border, 0.6)
      }

      Repeater {
        model: root.model.choices.slice(0, 8)

        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 34
          spacing: root.theme.smallGap

          Text {
            text: modelData.key
            color: root.theme.accent
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.bodySize
            font.weight: Font.Bold
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            text: modelData.icon
            visible: modelData.icon !== ""
            color: root.theme.muted
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.bodySize
          }

          Text {
            Layout.fillWidth: true
            text: modelData.label
            color: root.theme.foreground
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.captionSize
            elide: Text.ElideRight
          }

          Text {
            text: modelData.action ? "" : "›"
            color: root.theme.muted
            font.family: root.theme.fontFamily
            font.pixelSize: root.theme.bodySize
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.model.choices.length > 8
        text: "+ " + (root.model.choices.length - 8) + " more · ? to reveal"
        color: root.theme.muted
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.captionSize
      }

      Text {
        Layout.fillWidth: true
        visible: root.model.statusMessage !== "" || root.model.errorMessage !== ""
        text: root.model.errorMessage || root.model.statusMessage
        color: root.model.phase === "error" ? root.theme.urgent : root.theme.muted
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.captionSize
        wrapMode: Text.Wrap
      }
    }
  }
}
