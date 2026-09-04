import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property var setupModel: ({ phase: "scanning", candidates: [], selectedIndex: 0, errorMessage: "", currentBinding: "" })
  property var theme: ({
    panelPadding: 20, radius: 12, mediumGap: 14, smallGap: 8,
    background: "#101315", foreground: "#cacccc", border: "#707880",
    muted: "#707880", accent: "#cacccc", urgent: "#a55555",
    selectedBackground: "#202426", selectedBorder: "#303638",
    fontFamily: "sans-serif", titleSize: 20, bodySize: 14, captionSize: 12
  })

  implicitWidth: 680
  implicitHeight: 520

  Rectangle {
    anchors.fill: parent
    radius: Math.max(10, root.theme.radius)
    color: root.theme.background
    border.color: root.setupModel.phase === "error" ? root.theme.urgent : root.theme.border
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: root.theme.panelPadding
      spacing: root.theme.mediumGap

      RowLayout {
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: "Choose a leader key"
          color: root.theme.foreground
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.titleSize
          font.weight: Font.DemiBold
        }

        Text {
          text: "SETUP"
          color: root.theme.accent
          font.family: root.theme.fontFamily
          font.pixelSize: root.theme.captionSize
          font.weight: Font.Bold
        }
      }

      Text {
        Layout.fillWidth: true
        text: "Existing Omarchy shortcuts are never replaced automatically. The selected binding is backed up, applied atomically, and validated before it is kept."
        color: root.theme.muted
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.bodySize
        wrapMode: Text.Wrap
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.setupModel.phase === "selecting"
        spacing: root.theme.smallGap

        Repeater {
          model: root.setupModel.candidates

          delegate: Rectangle {
            required property int index
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: Math.max(7, root.theme.radius * 0.75)
            color: index === root.setupModel.selectedIndex
              ? root.theme.selectedBackground
              : "transparent"
            border.color: index === root.setupModel.selectedIndex
              ? root.theme.accent
              : root.theme.selectedBorder
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14

              Text {
                text: index === root.setupModel.selectedIndex ? "›" : " "
                color: root.theme.accent
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.bodySize
              }

              Text {
                Layout.preferredWidth: 210
                text: String(modelData.binding).toUpperCase()
                color: modelData.available ? root.theme.foreground : root.theme.muted
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.bodySize
                font.weight: Font.DemiBold
              }

              Text {
                Layout.fillWidth: true
                text: modelData.available ? "Available" : modelData.description
                color: modelData.available ? root.theme.accent : root.theme.urgent
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.captionSize
                elide: Text.ElideRight
              }

              Text {
                text: modelData.available ? "✓" : "×"
                color: modelData.available ? root.theme.accent : root.theme.urgent
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.bodySize
              }
            }
          }
        }
      }

      Item { Layout.fillHeight: true }

      Text {
        Layout.fillWidth: true
        visible: root.setupModel.phase === "scanning" || root.setupModel.phase === "applying"
        text: root.setupModel.phase === "scanning" ? "Inspecting live Hyprland bindings…" : "Applying and validating binding…"
        color: root.theme.accent
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.bodySize
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        Layout.fillWidth: true
        visible: root.setupModel.phase === "error"
        text: root.setupModel.errorMessage + "\n\nPress r to rescan."
        color: root.theme.urgent
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.bodySize
        wrapMode: Text.Wrap
      }

      Text {
        Layout.fillWidth: true
        visible: root.setupModel.phase === "success"
        text: "Leader installed on " + String(root.setupModel.currentBinding).toUpperCase() + ".\nPress Enter to close."
        color: root.theme.accent
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.bodySize
        horizontalAlignment: Text.AlignHCenter
      }

      RowLayout {
        Layout.fillWidth: true

        Text {
          Layout.fillWidth: true
          text: root.setupModel.phase === "selecting" ? "↑/↓ choose    enter apply" : ""
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
