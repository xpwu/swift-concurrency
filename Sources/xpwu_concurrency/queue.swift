//
//  File.swift
//  
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

class node<E> {
	var isValid: Bool = true
	var element: E
	var next: node<E>? = nil
	
	init(_ e: E) {
		element = e
	}
	
	func inValid() {
		self.isValid = false
	}
}

class queue<E> {
	var first: node<E>? = nil
	var last: node<E>? = nil
	var count: Int = 0
	
	func en(_ e: E)->node<E> {
		// is empty
		defer {
			self.count += 1
		}
		
		let newNode = node(e)
		guard let last = last else {
			self.last = newNode
			first = self.last
			return newNode
		}
		
		last.next = newNode
		self.last = last.next
		return newNode
	}
	
	func de()-> E? {
		while self.first != nil && !first!.isValid {
			self.first = first!.next
			self.count -= 1
		}
		
		guard let first = first else {
			return nil
		}

		let ret = first.element
		self.first = first.next
		
		// empty
		if self.first == nil {
			self.last = nil
			self.count = 0
		}
		
		self.count -= 1
		
		return ret
	}
}

