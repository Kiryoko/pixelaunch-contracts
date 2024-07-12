const fs = require('fs');
const inquirer = require('inquirer');
const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    let broadcast_args = "";
    let env_args = "";

    if (hre.network.name === "localhost") {
        env_args = "DEPLOYMENT_CONTEXT=localhost";
    }

    console.log(`Using network ${hre.network.name}`);

    const foundry = hre.userConfig.foundry;
    await hre.run("check-console-log", { path: foundry.src });

    let live = false


    let script = `${foundry.script}/${taskArgs.script}.s.sol`;

    if (!fs.existsSync(script)) {
        console.error(`Script ${taskArgs.script} does not exist`);
        process.exit(1);
    }

    if (taskArgs.broadcast) {
        broadcast_args = "--broadcast";

        if (!taskArgs.noConfirm) {
            const answers = await inquirer.prompt([
                {
                    name: 'confirm',
                    type: 'confirm',
                    default: false,
                    message: `This is going to: \n\n- Run Forge script ${taskArgs.script} on ${hre.network.name} \n\nAre you sure?`,
                }
            ]);

            if (answers.confirm === false) {
                process.exit(0);
            }
        }

        live = true;
        await shell.exec(`rm -rf ${foundry.broadcast}`, { silent: true });
    }

    if (!process.env.PRIVATE_KEY && !process.env.KEYSTORE_PATH) {
        console.error("Either PRIVATE_KEY or KEYSTORE_PATH must be set in the environment");
        process.exit(1);
    }

    const senderAuthentication = process.env.PRIVATE_KEY ? "--private-key" : "--keystore";

    let extraArgs = (taskArgs.extra || []).reduce((acc, arg) => {
        return acc + `${arg} `;
    }, "");

    cmd = `${env_args} forge script ${script} --sig ${taskArgs.function} --rpc-url ${hre.network.config.url} ${broadcast_args} ${extraArgs} ${hre.network.config.forgeDeployExtraArgs || ""} --slow ${senderAuthentication} *******`.replace(/\s+/g, ' ');
    console.log(cmd);
    result = await shell.exec(cmd.replace('*******', process.env.PRIVATE_KEY ?? process.env.KEYSTORE_PATH), { fatal: false });

    if (result.code != 0) {
        process.exit(result.code);
    }
}
