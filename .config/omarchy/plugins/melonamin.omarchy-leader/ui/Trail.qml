import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property var model: ({ path: [], typedKeys: [], phase: "active", errorMessage: "", statusMessage: "" })
  property var theme: ({
    panelPadding: 20, smallGap: 8, background: "#101315",
    foreground: "#cacccc", border: "#707880", muted: "#707880",
    accent: "#cacccc", urgent: "#a55555", selectedBackground: "#202426",
    fontFamily: "sans-serif", titleSize: 20, bodySize: 14, captionSize: 12
  })

  implicitWidth: Math.min(760, Math.max(300, trailRow.implicitWidth + theme.panelPadding * 2))
  implicitHeight: 64

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.theme.background
    border.color: root.model.phase === "error" ? root.theme.urgent : root.theme.border
    border.width: 1

    RowLayout {
      id: trailRow
      anchors.fill: parent
      anchors.leftMargin: root.theme.panelPadding
      anchors.rightMargin: root.theme.panelPadding
      spacing: root.theme.smallGap

      Text {
        text: "󱓞"
        color: root.theme.accent
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.titleSize
      }

      Text {
        text: {
          var labels = ["Home"]
          for (var i = 0; i < root.model.path.length; i++) labels.push(root.model.path[i].label)
          return labels.join("  ›  ")
        }
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.bodySize
        elide: Text.ElideMiddle
        Layout.maximumWidth: 500
      }

      Rectangle {
        Layout.preferredWidth: typed.implicitWidth + 18
        Layout.preferredHeight: 34
        radius: 17
        color: root.theme.selectedBackground

        Text {
          id: typed
          anchors.centerIn: parent
          text: (root.model.typedKeys.join(" ") || "_") + (root.model.phase === "active" ? "  _" : "")
          color: root.model.phase === "error" ? root.theme.urgent : root.theme.accent
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.bodySize
          font.weight: Font.Bold
        }
      }

      Text {
        visible: root.model.statusMessage !== "" || root.model.errorMessage !== ""
        text: root.model.errorMessage || root.model.statusMessage
        color: root.model.phase === "error" ? root.theme.urgent : root.theme.muted
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.captionSize
        elide: Text.ElideRight
        Layout.maximumWidth: 220
      }
    }
  }
}
