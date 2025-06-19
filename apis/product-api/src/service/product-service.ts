import {
  type sendUnaryData,
  type ServerUnaryCall,
  status,
} from "@grpc/grpc-js";
import {
  GetProductRequest,
  GetProductResponse,
  ListProductsRequest,
  ListProductsResponse,
  CreateProductRequest,
  CreateProductResponse,
  UpdateProductRequest,
  UpdateProductResponse,
  DeleteProductRequest,
  DeleteProductResponse,
  GetInventoryRequest,
  GetInventoryResponse,
  Product as ProductProto,
  Inventory as InventoryProto,
} from "../generated/product.js";
import {
  ProductRepository,
  type Product,
  type Inventory,
} from "../data/products.js";

function productToProto(product: Product): ProductProto {
  return {
    id: product.id,
    name: product.name,
    description: product.description,
    price: product.price,
    category: product.category,
    sku: product.sku,
    createdAt: product.createdAt,
    updatedAt: product.updatedAt,
  };
}

function inventoryToProto(inv: Inventory): InventoryProto {
  return {
    productId: inv.productId,
    quantity: inv.quantity,
    warehouseId: inv.warehouseId,
    lastRestocked: inv.lastRestocked,
  };
}

// Error handling utilities
function validateId<T extends {}>(
  id: string,
  callback: sendUnaryData<T>
): boolean {
  if (!id) {
    callback({
      code: status.INVALID_ARGUMENT,
      details: "Product ID is required",
    });
    return false;
  }
  return true;
}

function handleNotFound<T extends {}>(
  id: string,
  callback: sendUnaryData<T>
): void {
  callback({
    code: status.NOT_FOUND,
    details: `Product with ID ${id} not found`,
  });
}

export const productServiceImplementation = {
  getProduct: (
    call: ServerUnaryCall<GetProductRequest, GetProductResponse>,
    callback: sendUnaryData<GetProductResponse>
  ) => {
    const id = call.request.id;
    if (!validateId(id, callback)) return;

    const product = ProductRepository.getById(id);
    if (!product) {
      return handleNotFound(id, callback);
    }

    const response: GetProductResponse = {
      product: productToProto(product),
    };
    callback(null, response);
  },

  listProducts: (
    call: ServerUnaryCall<ListProductsRequest, ListProductsResponse>,
    callback: sendUnaryData<ListProductsResponse>
  ) => {
    const pageSize = call.request.pageSize || 10;
    const pageToken = call.request.pageToken || "";
    const category = call.request.category || undefined;
    const minPrice = call.request.minPrice || undefined;
    const maxPrice = call.request.maxPrice || undefined;

    const result = ProductRepository.paginate(
      pageSize,
      pageToken,
      category,
      minPrice,
      maxPrice
    );
    const response: ListProductsResponse = {
      products: result.products.map(productToProto),
      nextPageToken: result.nextPageToken,
      totalCount: result.totalCount,
    };

    callback(null, response);
  },

  createProduct: (
    call: ServerUnaryCall<CreateProductRequest, CreateProductResponse>,
    callback: sendUnaryData<CreateProductResponse>
  ) => {
    const name = call.request.name;
    const description = call.request.description;
    const price = call.request.price;
    const category = call.request.category;
    const sku = call.request.sku;

    if (!name || !description || !price || !category || !sku) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: "Name, description, price, category, and SKU are required",
      });
    }

    const product = ProductRepository.create({
      name,
      description,
      price,
      category,
      sku,
    });
    const response: CreateProductResponse = {
      product: productToProto(product),
    };

    callback(null, response);
  },

  updateProduct: (
    call: ServerUnaryCall<UpdateProductRequest, UpdateProductResponse>,
    callback: sendUnaryData<UpdateProductResponse>
  ) => {
    const id = call.request.id;
    const name = call.request.name;
    const description = call.request.description;
    const price = call.request.price;
    const category = call.request.category;

    if (!validateId(id, callback)) return;

    const updateData: Partial<Omit<Product, "id" | "createdAt">> = {};
    if (name) updateData.name = name;
    if (description) updateData.description = description;
    if (price) updateData.price = price;
    if (category) updateData.category = category;

    const product = ProductRepository.update(id, updateData);
    if (!product) {
      return handleNotFound(id, callback);
    }

    const response: UpdateProductResponse = {
      product: productToProto(product),
    };

    callback(null, response);
  },

  deleteProduct: (
    call: ServerUnaryCall<DeleteProductRequest, DeleteProductResponse>,
    callback: sendUnaryData<DeleteProductResponse>
  ) => {
    const id = call.request.id;
    if (!validateId(id, callback)) return;

    const success = ProductRepository.delete(id);
    if (!success) {
      return handleNotFound(id, callback);
    }

    const response: DeleteProductResponse = {
      success: true,
    };

    callback(null, response);
  },

  getInventory: (
    call: ServerUnaryCall<GetInventoryRequest, GetInventoryResponse>,
    callback: sendUnaryData<GetInventoryResponse>
  ) => {
    const productId = call.request.productId;
    if (!validateId(productId, callback)) return;

    const inventoryItems = ProductRepository.getInventory(productId);
    const totalQuantity = ProductRepository.getTotalQuantity(productId);

    const response: GetInventoryResponse = {
      inventory: inventoryItems.map(inventoryToProto),
      totalQuantity: totalQuantity,
    };

    callback(null, response);
  },
};
