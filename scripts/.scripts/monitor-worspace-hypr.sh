#!/bin/sh

numberWorkspace=$1

workspacePerMonitor=10
monitorsCount=$(hyprctl monitors | grep Monitor | wc -l)
workspaceId=$(hyprctl activeworkspace | grep workspace | awk '{print $3}')
monitorId=$(hyprctl activeworkspace | grep monitorID | awk '{print $2}')

workspace=$(($numberWorkspace + ($monitorId * $workspacePerMonitor)))

hyprctl dispatch workspace $workspace
