/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick 2.11
import QtQuick.Controls 2.4
import QtQml.Models 2.2
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

import "qrc:///util/" as Util
import "qrc:///widgets/" as Widgets
import "qrc:///style/"

NavigableFocusScope {
    id: root

    //forwarded from subview
    signal actionForSelection( var selection )
    signal contextMenuButtonClicked(Item menuParent, var menuModel)
    signal rightClick(Item menuParent, var menuModel)

    property var sortModel: []
    property Component colDelegate: Widgets.ListLabel {
        property var rowModel: parent.rowModel
        property var model: parent.colModel

        anchors.fill: parent
        text: !rowModel ? "" : (rowModel[model.criteria] || "")
    }
    property Component headerDelegate: Widgets.CaptionLabel {
        text: model.text || ""
    }

    property alias model: view.model

    property alias contentHeight: view.contentHeight

    property alias interactive: view.interactive

    property alias section: view.section

    property alias currentIndex: view.currentIndex
    property alias currentItem: view.currentItem

    property alias headerItem: view.headerItem
    property color headerColor

    property alias selectionModel: selectionModel
    property real rowHeight: VLCStyle.fontHeight_normal + VLCStyle.margin_large
    property alias spacing: view.spacing
    property int horizontalSpacing: VLCStyle.column_margin_width

    Accessible.role: Accessible.Table

    function positionViewAtIndex(index, mode) {
        view.positionViewAtIndex(index, mode)
    }

    Util.SelectableDelegateModel {
        id: selectionModel

        model: root.model
    }


    KeyNavigableListView {
        id: view

        anchors.fill: parent

        focus: true

        headerPositioning: ListView.OverlayHeader

        header: Rectangle {
            width: parent.width
            height: childrenRect.height
            color: headerColor
            visible: view.modelCount > 0
            z: 3

            Column {
                width: parent.width
                height: childrenRect.height

                Row {
                    anchors {
                        leftMargin: VLCStyle.margin_xxxsmall
                        rightMargin: VLCStyle.margin_xxxsmall
                        horizontalCenter: parent.horizontalCenter
                    }
                    height: childrenRect.height + VLCStyle.margin_xxsmall
                    topPadding: VLCStyle.margin_xxsmall
                    spacing: root.horizontalSpacing

                    Repeater {
                        model: sortModel
                        MouseArea {
                            height: childrenRect.height
                            width: modelData.width || 1
                            //Layout.alignment: Qt.AlignVCenter

                            Loader {
                                property var model: modelData

                                sourceComponent: model.headerDelegate || root.headerDelegate
                            }

                            Text {
                                text: (root.model.sortOrder === Qt.AscendingOrder) ? "▼" : "▲"
                                visible: root.model.sortCriteria === modelData.criteria
                                font.pixelSize: VLCStyle.fontSize_normal
                                color: VLCStyle.colors.accent
                                anchors {
                                    right: parent.right
                                    leftMargin: VLCStyle.margin_xsmall
                                    rightMargin: VLCStyle.margin_xsmall
                                }
                            }
                            onClicked: {
                                if (root.model.sortCriteria !== modelData.criteria)
                                    root.model.sortCriteria = modelData.criteria
                                else
                                    root.model.sortOrder = (root.model.sortOrder === Qt.AscendingOrder) ? Qt.DescendingOrder : Qt.AscendingOrder
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: VLCStyle.colors.textInactive
                }
            }
        }

        delegate:Rectangle {
            id: lineView

            width: view.width
            height: root.rowHeight
            color: VLCStyle.colors.getBgColor(selected, hoverArea.containsMouse, lineView.activeFocus)

            property var rowModel: model
            property bool selected: selectionModel.isSelected(root.model.index(index, 0))
            Connections {
                target: selectionModel
                onSelectionChanged: lineView.selected = selectionModel.isSelected(root.model.index(index, 0))
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                Keys.onMenuPressed: root.contextMenuButtonClicked(contextButton,rowModel)
                acceptedButtons: Qt.RightButton | Qt.LeftButton

                onClicked: {
                    selectionModel.updateSelection( mouse.modifiers , view.currentIndex, index)
                    view.currentIndex = rowModel.index
                    lineView.forceActiveFocus()

                    if (mouse.button === Qt.RightButton){
                        root.rightClick(lineView,rowModel)
                    }
                }

                onDoubleClicked: {
                    actionForSelection(selectionModel.selectedIndexes)
                }

                Row {
                    anchors {
                        topMargin: VLCStyle.margin_xxsmall
                        bottomMargin: VLCStyle.margin_xxsmall
                        leftMargin: VLCStyle.margin_xxxsmall
                        rightMargin: VLCStyle.margin_xxxsmall
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        bottom: parent.bottom
                    }

                    spacing: root.horizontalSpacing

                    Repeater {
                        model: sortModel

                        Item {
                            height: parent.height
                            width: modelData.width || 1
                            Layout.alignment: Qt.AlignVCenter

                            SmoothedAnimation on width {
                                duration: 256
                                easing.type: Easing.OutCubic
                            }

                            Loader{
                                property var rowModel: lineView.rowModel
                                property var colModel: modelData

                                anchors.fill: parent
                                sourceComponent: colModel.colDelegate || root.colDelegate

                            }
                        }
                    }
                }
            }
        }

        onSelectAll: selectionModel.selectAll()
        onSelectionUpdated: selectionModel.updateSelection( keyModifiers, oldIndex, newIndex )
        onActionAtIndex: root.actionForSelection( selectionModel.selectedIndexes )

        navigationParent: root
    }

    /*
     *define the intial position/selection
     * This is done on activeFocus rather than Component.onCompleted because delegateModel.
     * selectedGroup update itself after this event
     */
    onActiveFocusChanged: {
        if (activeFocus && view.count > 0 && !selectionModel.hasSelection) {
            var initialIndex = 0
            if (view.currentIndex !== -1)
                initialIndex = view.currentIndex
            selectionModel.select(model.index(initialIndex, 0), ItemSelectionModel.ClearAndSelect)
            view.currentIndex = initialIndex
        }
    }

}
