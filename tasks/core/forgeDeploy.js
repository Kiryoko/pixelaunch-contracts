const fs = require('fs');
const inquirer = require('inquirer');
const shell = require('shelljs');

module.exports = async function (taskArgs, hre) {
    let broadcast_args = "";
    let verify_args = "";
    let env_args = "";
    let use_existing_anvil = true;
    let kill_anvil_after_deployment = false;
    let anvilProcessId;

    if (hre.network.name === "localhost") {
        env_args = "DEPLOYMENT_CONTEXT=localhost";
        taskArgs.verify = false;

        if (use_existing_anvil) {
            console.log("Checking if there's an existing Anvil process...");
            anvilProcessId = shell.exec('pgrep anvil', { silent: true }).stdout.trim();
        }

        if (!anvilProcessId) {
            console.log("Starting Anvil...");
            anvilProcessId = shell.exec('killall -9 anvil; anvil > /dev/null 2>&1 & echo $!', { silent: true, fatal: true }).stdout.trim();
        }
    }

    console.log(`Using network ${hre.network.name}`);

    const foundry = hre.userConfig.foundry;
    await hre.run("check-console-log", { path: foundry.src });

    const apiKey = hre.network.config.api_key;
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
                    message: `This is going to: \n\n- Deploy contracts to ${hre.network.name} ${taskArgs.verify ? "\n- Verify contracts" : "\n- Leave the contracts unverified"} \n\nAre you sure?`,
                }
            ]);

            if (answers.confirm === false) {
                process.exit(0);
            }
        }

        live = true;
        await shell.exec(`rm -rf ${foundry.broadcast}`, { silent: true });
    }

    if (taskArgs.verify) {
        if (apiKey) {
            verify_args = `--verify --etherscan-api-key ${apiKey}`;
        } else {
            const answers = await inquirer.prompt([
                {
                    name: 'confirm',
                    type: 'confirm',
                    default: false,
                    message: `You are trying to verify contracts on ${hre.network.name} without an etherscan api key. \n\nAre you sure?`
                }
            ]);

            if (answers.confirm === false) {
                process.exit(0);
            }

            verify_args = `--verify`;
        }
    }

    if (!process.env.PRIVATE_KEY && !process.env.KEYSTORE_PATH) {
        console.error("Either PRIVATE_KEY or KEYSTORE_PATH must be set in the environment");
        process.exit(1);
    }

    const deployerAuthentication = process.env.PRIVATE_KEY ? "--private-key" : "--keystore";

    cmd = `${env_args} forge script ${script} --rpc-url ${hre.network.config.url} ${broadcast_args} ${verify_args} ${taskArgs.extra || ""} ${hre.network.config.forgeDeployExtraArgs || ""} --slow ${deployerAuthentication} *******`.replace(/\s+/g, ' ');
    console.log(cmd);
    result = await shell.exec(cmd.replace('*******', process.env.PRIVATE_KEY ?? process.env.KEYSTORE_PATH), { fatal: false });
    await shell.exec("./forge-deploy sync", { silent: true });
    await hre.run("post-deploy");

    if (result.code != 0) {
        process.exit(result.code);
    }

    if (anvilProcessId && kill_anvil_after_deployment) {
        console.log("Stopping Anvil...");
        await shell.exec(`kill ${anvilProcessId}`, { silent: true });
    }
}
