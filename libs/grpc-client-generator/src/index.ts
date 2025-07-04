export interface GeneratorOptions {
	services: ServiceConfig[];
}

export interface ServiceConfig {
	name: string;
	outputDir: string;
	protoFile: string;
}

export const generateClients = (options: GeneratorOptions): void => {
	const { services } = options;

	for (const service of services) {
		const { name, outputDir, protoFile } = service;
		console.log("Hello world");
		console.log(name, outputDir, protoFile);
	}
};
