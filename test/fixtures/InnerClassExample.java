package com.example.test;

public class OuterClass {

    public static class StaticInnerClass {
        private String value;
    }

    public class InnerClass {
        private int count;

        public class DeeplyNestedClass {
            private boolean flag;
        }
    }

    private class PrivateInnerClass {
        private double amount;
    }
}
