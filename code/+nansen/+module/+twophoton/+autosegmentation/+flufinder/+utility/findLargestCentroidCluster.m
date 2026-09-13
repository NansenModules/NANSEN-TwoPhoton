function isInLargestCluster = findLargestCentroidCluster(points, radius)
%findLargestCentroidCluster Members of the largest group of points linked within a radius
%
%   isInLargestCluster = findLargestCentroidCluster(points, radius) groups
%   the rows of points (n-by-2 coordinates) into clusters in which every
%   member lies within radius of at least one other member (single
%   linkage) and returns a logical column marking the members of the
%   largest cluster. When clusters tie in size, the one containing the
%   lowest-numbered point wins, so the result is deterministic.
%
%   FluFinder uses this to separate the centroids of components that
%   share a pixel but belong to different cells. It replaces the
%   linkage/cluster pair from the Statistics and Machine Learning Toolbox,
%   which agglomerated by centroid distance with the same cutoff.

    arguments
        points (:, 2) double
        radius (1,1) double {mustBePositive}
    end

    numPoints = size(points, 1);
    isInLargestCluster = false(numPoints, 1);
    if numPoints == 0
        return
    end

    deltaX = points(:, 1) - points(:, 1)';
    deltaY = points(:, 2) - points(:, 2)';
    isLinked = sqrt(deltaX.^2 + deltaY.^2) <= radius;

    % Flood-fill the link graph to label connected groups.
    clusterId = zeros(numPoints, 1);
    numClusters = 0;
    for iPoint = 1:numPoints
        if clusterId(iPoint) ~= 0
            continue
        end
        numClusters = numClusters + 1;
        toVisit = iPoint;
        while ~isempty(toVisit)
            current = toVisit(1);
            toVisit(1) = [];
            if clusterId(current) ~= 0
                continue
            end
            clusterId(current) = numClusters;
            unvisitedNeighbours = find(isLinked(current, :) & clusterId' == 0);
            toVisit = [toVisit, unvisitedNeighbours]; %#ok<AGROW>
        end
    end

    clusterSizes = accumarray(clusterId, 1);
    [~, largestCluster] = max(clusterSizes);
    isInLargestCluster = clusterId == largestCluster;
end
