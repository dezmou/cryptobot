const fetch = require("node-fetch");
const secrets = require("./secret");

const sendNotification = async (title, message) => {
    const params = {
        token: secrets.notif_token,
        user: secrets.notif_user,
        message,
        sound: "cashregister",
        title
    }
    let paramsStr = "";
    for (let param of Object.entries(params)) {
        paramsStr += `${param[0]}=${param[1]}&`
    }
    const res = await fetch(`https://api.pushover.net/1/messages.json?${paramsStr}`, {
        method: "POST",
    });
}

module.exports = sendNotification;