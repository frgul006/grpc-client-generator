import { sendUnaryData, ServerUnaryCall, status } from '@grpc/grpc-js';
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
  Inventory as InventoryProto
} from '../generated/product_pb';
import { ProductRepository, Product, Inventory } from '../data/products';

function productToProto(product: Product): ProductProto {
  const productProto = new ProductProto();
  productProto.setId(product.id);
  productProto.setName(product.name);
  productProto.setDescription(product.description);
  productProto.setPrice(product.price);
  productProto.setCategory(product.category);
  productProto.setSku(product.sku);
  productProto.setCreatedAt(product.createdAt);
  productProto.setUpdatedAt(product.updatedAt);
  return productProto;
}

function inventoryToProto(inv: Inventory): InventoryProto {
  const inventoryProto = new InventoryProto();
  inventoryProto.setProductId(inv.productId);
  inventoryProto.setQuantity(inv.quantity);
  inventoryProto.setWarehouseId(inv.warehouseId);
  inventoryProto.setLastRestocked(inv.lastRestocked);
  return inventoryProto;
}

export const productServiceImplementation = {
  getProduct: (call: ServerUnaryCall<GetProductRequest, GetProductResponse>, callback: sendUnaryData<GetProductResponse>) => {
    const id = call.request.getId();
    console.log(`[Product Service] GetProduct called with ID: ${id}`);
    
    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    }

    const product = ProductRepository.getById(id);
    if (!product) {
      return callback({
        code: status.NOT_FOUND,
        details: `Product with ID ${id} not found`
      });
    }

    const response = new GetProductResponse();
    response.setProduct(productToProto(product));
    callback(null, response);
  },

  listProducts: (call: ServerUnaryCall<ListProductsRequest, ListProductsResponse>, callback: sendUnaryData<ListProductsResponse>) => {
    const pageSize = call.request.getPageSize() || 10;
    const pageToken = call.request.getPageToken() || '';
    const category = call.request.getCategory() || undefined;
    const minPrice = call.request.getMinPrice() || undefined;
    const maxPrice = call.request.getMaxPrice() || undefined;
    
    console.log(`[Product Service] ListProducts called - pageSize: ${pageSize}, pageToken: ${pageToken}, category: ${category}, minPrice: ${minPrice}, maxPrice: ${maxPrice}`);

    const result = ProductRepository.paginate(pageSize, pageToken, category, minPrice, maxPrice);
    const response = new ListProductsResponse();
    response.setProductsList(result.products.map(productToProto));
    response.setNextPageToken(result.nextPageToken);
    response.setTotalCount(result.totalCount);
    
    callback(null, response);
  },

  createProduct: (call: ServerUnaryCall<CreateProductRequest, CreateProductResponse>, callback: sendUnaryData<CreateProductResponse>) => {
    const name = call.request.getName();
    const description = call.request.getDescription();
    const price = call.request.getPrice();
    const category = call.request.getCategory();
    const sku = call.request.getSku();
    
    console.log(`[Product Service] CreateProduct called - name: ${name}, description: ${description}, price: ${price}, category: ${category}, sku: ${sku}`);

    if (!name || !description || !price || !category || !sku) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Name, description, price, category, and SKU are required'
      });
    }

    const product = ProductRepository.create({ name, description, price, category, sku });
    const response = new CreateProductResponse();
    response.setProduct(productToProto(product));
    
    callback(null, response);
  },

  updateProduct: (call: ServerUnaryCall<UpdateProductRequest, UpdateProductResponse>, callback: sendUnaryData<UpdateProductResponse>) => {
    const id = call.request.getId();
    const name = call.request.getName();
    const description = call.request.getDescription();
    const price = call.request.getPrice();
    const category = call.request.getCategory();
    
    console.log(`[Product Service] UpdateProduct called - id: ${id}, name: ${name}, description: ${description}, price: ${price}, category: ${category}`);

    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    }

    const updateData: Partial<Omit<Product, 'id' | 'createdAt'>> = {};
    if (name) updateData.name = name;
    if (description) updateData.description = description;
    if (price) updateData.price = price;
    if (category) updateData.category = category;

    const product = ProductRepository.update(id, updateData);
    if (!product) {
      return callback({
        code: status.NOT_FOUND,
        details: `Product with ID ${id} not found`
      });
    }

    const response = new UpdateProductResponse();
    response.setProduct(productToProto(product));
    
    callback(null, response);
  },

  deleteProduct: (call: ServerUnaryCall<DeleteProductRequest, DeleteProductResponse>, callback: sendUnaryData<DeleteProductResponse>) => {
    const id = call.request.getId();
    console.log(`[Product Service] DeleteProduct called with ID: ${id}`);
    
    if (!id) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    }

    const success = ProductRepository.delete(id);
    if (!success) {
      return callback({
        code: status.NOT_FOUND,
        details: `Product with ID ${id} not found`
      });
    }

    const response = new DeleteProductResponse();
    response.setSuccess(true);
    
    callback(null, response);
  },

  getInventory: (call: ServerUnaryCall<GetInventoryRequest, GetInventoryResponse>, callback: sendUnaryData<GetInventoryResponse>) => {
    const productId = call.request.getProductId();
    console.log(`[Product Service] GetInventory called for product ID: ${productId}`);
    
    if (!productId) {
      return callback({
        code: status.INVALID_ARGUMENT,
        details: 'Product ID is required'
      });
    }

    const inventoryItems = ProductRepository.getInventory(productId);
    const totalQuantity = ProductRepository.getTotalQuantity(productId);

    const response = new GetInventoryResponse();
    response.setInventoryList(inventoryItems.map(inventoryToProto));
    response.setTotalQuantity(totalQuantity);
    
    callback(null, response);
  }
};