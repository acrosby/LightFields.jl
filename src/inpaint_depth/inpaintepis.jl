# Module for inpainting epis

using PyPlot
using Shearlab

getshearletsystem2D = Shearlab.getshearletsystem2D


# Normalized iterative thresholding

function inpaint2D(imgMasked,mask,iterations,stopFactor,shearletsystem)
    coeffs = Shearlab.sheardec2D(imgMasked,shearletsystem);
    coeffsNormalized = zeros(size(coeffs))+im*zeros(size(coeffs));
    for i in 1:shearletsystem.nShearlets
        coeffsNormalized[:,:,i] = coeffs[:,:,i]./shearletsystem.RMS[i];
    end
    delta = maximum(abs(coeffsNormalized[:]));
    lambda=(stopFactor)^(1/(iterations-1));
    imgInpainted = zeros(size(imgMasked));
    #iterative thresholding
    for it = 1:iterations
        res = mask.*(imgMasked-imgInpainted);
        coeffs = Shearlab.sheardec2D(imgInpainted+res,shearletsystem);
        coeffsNormalized = zeros(size(coeffs))+im*zeros(size(coeffs));
        for i in 1:shearletsystem.nShearlets
            coeffsNormalized[:,:,i] = coeffs[:,:,i]./shearletsystem.RMS[i];
        end
        coeffs = coeffs.*(abs(coeffsNormalized).>delta);
        imgInpainted = Shearlab.shearrec2D(coeffs,shearletsystem);  
        delta=delta*lambda;  
    end
    imgInpainted
end

# Normalized iterative thresholding with varying acceleration

function inpaint2D_accel(imgMasked,mask,iterations,stopFactor,shearletsystem)
    coeffs = Shearlab.sheardec2D(imgMasked,shearletsystem);
    coeffsNormalized = zeros(size(coeffs))+im*zeros(size(coeffs));
    for i in 1:shearletsystem.nShearlets
        coeffsNormalized[:,:,i] = coeffs[:,:,i]./shearletsystem.RMS[i];
    end
    delta = maximum(abs(coeffsNormalized[:]));
    lambda=(stopFactor)^(1/(iterations-1));
    imgInpainted = zeros(size(imgMasked));
    alpha = 1
    #iterative thresholding
    for it = 1:iterations
        res = mask.*(imgMasked-imgInpainted);
        coeffs = Shearlab.sheardec2D(imgInpainted+alpha*res,shearletsystem);
        coeffsNormalized = zeros(size(coeffs))+im*zeros(size(coeffs));
        for i in 1:shearletsystem.nShearlets
            coeffsNormalized[:,:,i] = coeffs[:,:,i]./shearletsystem.RMS[i];
        end
        coeffs = coeffs.*(abs(coeffsNormalized).>delta);
        # Support of coeffsNormalized until 
        norms = [norm(coeffs[:,:,i]) for i in 1:size(coeffs)[3]]
        # Thresholding the norm of the matrices to catch the support (smallest )
        indices = (norms.<0.5)
        beta = Shearlab.sheardec2D(res,shearletsystem);
        beta[(~indices)...] = 0;
        beta2 = mask.*(Shearlab.shearrec2D(beta,shearletsystem));
        alpha = sum((abs.(beta)).^2)/sum((abs.(beta2)).^2)
        imgInpainted = Shearlab.shearrec2D(coeffs,shearletsystem);  
        delta=delta*lambda;  
    end
    imgInpainted
end

# Function to inpaint file

function inpaint_file(path_epis, file_sparse,file_dense, stopFactor) 
    # The path of the sparse EPI
    name_sparse = path_epis*file_sparse;
    EPI_sparse = Shearlab.load_image(name_sparse, n,m);
    EPI_sparse = EPI_sparse[:,:,1];
    name_dense = path_epis*file_dense;
    EPI_dense = Shearlab.load_image(name_dense, n,m);
    EPI_dense = EPI_dense[:,:,1];
    #Initialize with ones 
    mask = ones(Float64,size(EPI_dense));
    mask[abs.(EPI_dense-EPI_sparse).!=0]=0
    # Data 
    EPI_masked = EPI_sparse.*mask;
    EPIinpainted50 = inpaint2D(EPI_masked,mask,50,stopFactor,shearletsystem);
    name_inpainted1 = split(name_dense,"/")
    name_inpainted1[4] = "Inpainted"
    last_name = name_inpainted1[5]
    last_name_split = split(last_name,"_")
    last_name_split[7] = "inpainted.png"
    last_name_split
    last_name = last_name_split[1]
    for i in 2:size(last_name_split)[1]
        last_name = last_name*"_"*last_name_split[i]
    end
    name_inpainted1[5] = last_name
    name_inpainted = name_inpainted1[1]
    for i in 2:size(name_inpainted1)[1]
        name_inpainted = name_inpainted*"/"*name_inpainted1[i]
    end
    name_inpainted
    Shearlab.imageplot(real(EPIinpainted50))
    savefig(name_inpainted, dpi = 80*3,bbox_inches="tight")
    clf()
end

function inpaint_files(path_to_epis) 
	# Inpainting all the sparse epis
	list_files = readdir(path_to_epis);
	list_files = list_files[2:length(list_files)]
	sparse_list = [];
	dense_list = [];

	for string in list_files
    	if split(string,"_")[7]=="sparse.png"
        	push!(sparse_list,string)
    	end
	end

	for string in list_files
  	if split(string,"_")[7]=="dense.png"
    	push!(dense_list,string)
		end
	end

	# Inpaint all the files
	for i in 1:length(sparse_list)
    file_sparse = sparse_list[i];
    file_dense = dense_list[i];
    inpaint_file(file_sparse,file_dense);
	end
end
