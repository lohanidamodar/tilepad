Generate Flutter app
clone of https://www.touch-portal.com/

Basic implementation of Touch portal a remote macros app. Where server lives in the computer and client is on the phone. The client connects to the server and sends commands to it. The server executes the commands and sends the results back to the client.

Server should be able to configure the button in the client. Each button should have a name, icon, and command. The command can be a shell command or a script. The server should be able to execute the command.

The client should be able to display the buttons and connect to the server. When button is pressed, the client should send the command to the server.

- org: dev.appwriters
- name: Tilepad

Generate project in the current folder
Both server and client should be in the same Flutter project. but the server and client should have different main.dart files. The server module should be in the server folder and the client module should be in the client folder. The server module should have a main.dart file that starts the server and the client module should have a main.dart file that starts the client. All common items between the server should be in their own folder based on their functionality


## folder structure
```
Tilepad
├── lib
│   ├── src
│   │   ├── client
│   │   │   ├── main.dart
│   │   │   ├── client.dart
│   │   ├── server
│   │   │   ├── main.dart
│   │   │   ├── server.dart
│   │   ├── ...
```
