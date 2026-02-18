package com.example.test;

import java.util.List;
import java.util.Map;

public class GenericClass<T extends Model> {
    private Map<String, List<ProductModel>> productCache;
    private List<T> items;

    public <R extends Result> R findById(String id) {
        return null;
    }
}
