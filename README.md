# macOS_external_app_man
auto create softlink for your external apps's softlink, so they can display in the macOS launcher panel

# Usage
1. download the shell script in this repo
2. fill your source dir (that you put externall .app files in), at the line 4, for example `/Volumes/my_external_driver/apps/`
3. (optional) edit your target dir if the default one doesn't match your needs. it was default as `~/Applications` which the lauch panel can read. 
4. give run permission for the script: `chmod +x refresh_external_apps.sh`
5. run script: `./refresh_external_apps.sh`
6. (optional) make alias if you want to run it with a bare command everywhere: add this (`alias YOUR_COMMAND='./refresh_external_apps.sh'`, for example `alias refreshexternalapps='./refresh_external_app.sh'`) to the end of your shell's config file (for example `~/.bashrc` `~/.zshrc` ) ; then restart terminal or `source` your terminal config file.