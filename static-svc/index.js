// Require the framework and instantiate it
const fastify = require("fastify")({ logger: false });

// Declare a route
fastify.get("*", async (request, reply) => {
  let result = "";
  for (let key of Object.keys(request.headers)) {
    result += `${key}=${request.headers[key]}\n`;
  }
  for (let key of Object.keys(process.env)) {
    result += `${key}=${process.env[key]}\n`;
  }
  reply.send(result);
});

// Run the server!
const start = async () => {
  try {
    const PORT = process.env.PORT;
    if (!PORT) {
      throw new Error("Missing PORT env");
    }
    await fastify.listen(PORT, "0.0.0.0");
    console.log("started server");
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};
start();

process.on("SIGTERM", async function () {
  console.log("SIGTERM: closing server");
  await fastify.close();
  console.log("successfully closed!");
  await new Promise((solved) => setTimeout(solved, 2000));
  console.log("process exited");
});
