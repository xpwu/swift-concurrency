//
//  File.swift
//  
//
//  Created by xpwu on 2024/9/25.
//

import Foundation

class node<E> {
	var element: E
	var next: node<E>? = nil
	
	init(_ e: E) {
		element = e
	}
}

class queue<E> {
	var first: node<E>? = nil
	var last: node<E>? = nil
	var count: Int = 0
	
	func en(_ e: E) {
		// is empty
		defer {
			self.count += 1
		}
		
		guard let last = last else {
			self.last = node(e)
			first = self.last
			return
		}
		
		last.next = node(e)
		self.last = last.next
	}
	
	func de()-> E? {
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

