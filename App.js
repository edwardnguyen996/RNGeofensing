import React, { Component } from "react";
import { StyleSheet, Text, View, Platform, TouchableHighlight } from "react-native";
import EventBridge from "react-native-event-bridge";
import Permission from 'react-native-permissions';

export default class App extends Component {

  async componentDidMount(): void {
    if(Platform.OS === "ios"){
      await Permission.request('location');
      await Permission.request('notification');
    }
  }

  startMonitoring = () => {
    requestAnimationFrame(() => {
      EventBridge.emitEvent(this, "StartGenfensingTracking");
    });
  };

  stopMonitoring = () => {
    requestAnimationFrame(() => {
      EventBridge.emitEvent(this, "StopGenfensingTracking");
    });
  };

  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome}>Welcome to React Native!</Text>
        <Text style={styles.instructions}>A demo of Geofencing</Text>
        <View style={{ flexDirection: "row" }}>
          <TouchableHighlight
            onPress={this.startMonitoring}
            underlayColor="#ddd"
            style={styles.button}
          >
            <Text>Start tracking</Text>
          </TouchableHighlight>
          <TouchableHighlight
            onPress={this.stopMonitoring}
            underlayColor="#ddd"
            style={styles.button}
          >
            <Text>Stop tracking</Text>
          </TouchableHighlight>
        </View>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#F5FCFF"
  },
  welcome: {
    fontSize: 20,
    textAlign: "center",
    margin: 10
  },
  instructions: {
    textAlign: "center",
    color: "#333333",
    marginBottom: 5
  },
  button: {
    width: 100,
    height: 48,
    margin: 10,
    borderRadius: 6,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#eee",
    marginTop: 80
  }
});
