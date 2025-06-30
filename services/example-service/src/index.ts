import { generateClients } from "grpc-client-generator";

generateClients({
	services: [
		{
			name: "ExampleService",
			outputDir: "src/generated",
			protoFile: "example.proto",
		},
	],
});
