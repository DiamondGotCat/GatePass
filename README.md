
<img width="1920" src="https://github.com/user-attachments/assets/4b6b0690-768b-46b4-b046-7f8daa2e2a03" />

# GatePass
macOS App to Remove com.apple.quarantine attribute from file or folder

## Overview
GatePass is a macOS app that removes the com.apple.quarantine attribute from files and folders.<br>
macOS has a security feature called Gatekeeper, which blocks apps that have not gone through Apple's App Notarization process from running.<br>
Gatekeeper's forced blocking does not occur when the com.apple.quarantine attribute is absent.<br>
If you try to run these apps with the com.apple.quarantine attribute still attached, the option to run them will not be displayed unless you open them from the context menu that appears when you Control-click the app.<br>
Furthermore, on recent macOS versions, even opening from the context menu does not allow execution.<br>
In such cases, you need to either disable Gatekeeper or remove the com.apple.quarantine attribute using the Terminal.<br>
However, unless you are a developer or have extensive knowledge of the Terminal, most users are not familiar with it.<br>
GatePass was created to solve this problem.<br>
GatePass allows you to easily remove the attribute by dragging and dropping files/folders or selecting them via a dialog.<br>
However, since this bypasses Gatekeeper, which is in place for security enhancement, you are solely responsible for its execution.
