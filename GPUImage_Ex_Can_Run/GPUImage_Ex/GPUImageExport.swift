//
//  GPUImageExport.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/18.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit
import GPUImage

public class GPUImageMovieExport {

    public var movieURL: URL?
    
    public var movieOutputURL: URL?
    // 如果有
    public var groupFilter: GPUImageFilterGroup?
    
    private var movieFile: GPUImageMovie?
    
    private var basicFilter: GPUImageFilter?
    
    private var movieWriter: GPUImageMovieWriter?
    

}

//class T {
//    let export = GPUImageMovieExport()
//
//    init() {
//        export.groupFilter?.addFilter(<#T##filter: (GPUImageOutput & GPUImageInput)##(GPUImageOutput & GPUImageInput)#>)
//        .addFilter(<#T##filter: (GPUImageOutput & GPUImageInput)##(GPUImageOutput & GPUImageInput)#>)
//
//        export.groupFilter?.filter(at: <#T##UInt#>)
//
//    }
//}

public extension GPUImageFilterGroup {
//    public func addGPUImageFilter(_ groupFilter: inout GPUImageFilterGroup, add filter: (GPUImageOutput & GPUImageInput)) -> Self {
//        self.addFilter(filter)
//        return self
//    }
    
    @discardableResult
    public func appendFilter(_ filter: (GPUImageOutput & GPUImageInput)) -> Self{
        self.addFilter(filter)
        self.initialFilters = [filter]
        self.terminalFilter = filter
        if self.filterCount() != 1 {
            let pre_filter: (GPUImageOutput & GPUImageInput) = self.filter(at: self.filterCount()-1)
            pre_filter.addTarget(filter)
            self.initialFilters = [self.filter(at: 0)]
            self.terminalFilter = filter
        }
        return self
    }
}

