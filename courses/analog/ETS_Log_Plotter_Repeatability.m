%***************************************************
%Log File Structure
%
%   First element
%   120 - file data
%   125 - file data
%   140 - file data
%   10 - {test #, number?, high limit, low limit, units, Test
%   100 - test result -> {test number, Alarm, P/F, Measurement
%   130 - site test info for previous data
%
%***************************************************

function ETS_Log_Plotter_Repeatability
% clear variables and close old figure windows
    close all    % comment out this line to keep old graphs open
    clear all
    
    fprintf('Repeatability\n');    
    
    numOfFiles = 1;
    
    % setup temporary counting variables and data arrays
    test_data = [];     % array of test parameters
    site = []; 
    
    %Dimensions for figures
    subPlotX = 2; %Number of subplots in the X direction for each figure
    subPlotY = 2; %Number of subplots in the Y direction for each figure
   
    for fileNum = 1:numOfFiles
        % open the data file to be plotted
        fid = fopen(input('Name of file: ','s'),'r+');
        siteChoice = str2double(input('For this file, choose test site: ','s'));
        % extract information from file
        line = 0;
        countOfTests(fileNum,[1 2]) = 0;       % variables to manage the measurement data array
        test = 0;
        valueTemp = [];
        while (line ~= -1)  % stop reading at the end of the file
            line = fgetl(fid);  % import the next line from the file
            if(line == -1)      % stop if there are no more lines
                break
            end
            array = regexp(line,',','split');   %read the file by line and split each line at commas (,)
            array = strrep(array, '"','');      %remove quotations from the input array
            type = str2double(array(1));        %convert the first element to double format
            if(type == 120 || type == 125 || type == 140)   % determine the data type for the line
                % ignore ETS file information
            elseif(type == 10)                              % test parameters
                column = [array(2:7)];
                test_data = cat(1,test_data, column);
            elseif(type == 100)                             % test results by chip
                test = test + 1;                            % move to the next row of the data arrays                          
                valueTemp(test) = str2double(array(5));     % for a result line, get the measurement
            elseif(type == 130)                             % site information
                finalRow = test;
                siteNum = str2double(array(2));
                countOfTests(fileNum,siteNum) = countOfTests(fileNum,siteNum) + 1;
                for test = 1:finalRow
                    site(fileNum,test,countOfTests(fileNum,siteNum),siteNum) = valueTemp(test);   % The site array is 4D, dimensions: file, test, value, site
                end
                test = 0;
            end
        end
        %VERY IMPORTANT
        %The number of tests, and test limits determined by File 1
        if(fileNum == 1) 
            numOfMeasures = countOfTests(fileNum,siteChoice(fileNum));                                 % number of chips tested performed (data points/graph)
            x = 1:numOfMeasures;                                            % create the x-axis plotting vector
            numOfTests = size(test_data,1);                              % number of defferent tests performed
            t_lim = (1:numOfMeasures); 
            for j = 1:numOfMeasures
                t_lim(j) = 1;
            end
        end
        fclose(fid);
    end
    
    % Generate histogram for each test
    res = str2double(input('Number of bars in histogram (50 is a nice starting choice): ','s'));
    figure
    subPlotCount = 0; %Sets counters for first figure
    figureCount = 0;
    for whichTest = 1:numOfTests     % iterate over each test and pull each measurement
        minimum = str2double(test_data(whichTest,4));         % control width of x-axis
        maximum = str2double(test_data(whichTest,3));         % control width of x-axis
        low = str2double(test_data(whichTest,4));             % check for upper and lower datasheet limits
        high = str2double(test_data(whichTest,3));
        test_result = 1:(numOfMeasures.*numOfFiles);
        for fileNum = 1:numOfFiles                                 % for all files
            if(countOfTests(fileNum,siteChoice) <= 0)
                fprintf('Error: no data was measured for file %d site %d, please select a different site.\n',fileNum,siteChoice(fileNum));
                clear all
                close all
                return;
            end
            for testNum = 1:numOfMeasures                             % for all tests
                m1 = site(fileNum,whichTest,testNum,siteChoice);
                if(m1 < minimum || isnan(minimum))      % find the minimum and maximum value to be 
                    minimum = m1;                       % graphed
                end
                if(m1 > maximum || isnan(maximum))
                    maximum = m1;
                end
                test_result(testNum) = m1;                    % create 1D array of all test results
            end
        end
        subPlotCount = subPlotCount + 1;
        if(subPlotCount > subPlotX*subPlotY)            %If there is no more room on the current figure make a new one
            figure
            figureCount = figureCount + 1;  
            subPlotCount = 1;                               %Resets counter
        end
        subplot(subPlotX,subPlotY,(whichTest-figureCount*(subPlotX*subPlotY)));  %Places subplot on figure                           % enter subplot for specific test
        hold on
        xlabel(test_data(whichTest,5));                     % setup graph
        ylabel('Devices');
        title(test_data(whichTest,6));
        x_axis = linspace(minimum, maximum, res);   % create x-axis vector
        h_gram = histc(test_result,x_axis);         % generate histogram vector
        mu = mean(test_result);                     % generate mu and sigma
        sigma = (mean((test_result-mu).^2)).^(.5);
        if(isnan(str2double(test_data(whichTest,3))))                   % calculate cp, cpk
            % no upper datasheet limit
            cp = (mu - low)/(3*sigma);
            cpk = cp;
        elseif(isnan(str2double(test_data(whichTest,4))))
            cp = (high - mu)/(3*sigma);
            cpk = cp;
        else
            cp = (high - low)/(6*sigma);
            cpk_1 = (high - mu)/(3*sigma);
            cpk_2 = (mu - low)/(3*sigma);
            cpk = min([cpk_1,cpk_2]);
        end
        grr = 100/cp;
        q = size(h_gram,2);             

        % printing statistical information
        name = test_data(whichTest,6);
        fprintf('\n');                              % output statistical information for each test
        fprintf('%c',char(name));
        fprintf('\n\tmu = %f\n',mu);
        fprintf('\tsigma = %f\n',sigma);
        fprintf('\tCp = %f\n', cp);
        fprintf('\tCpk = %f\n', cpk);
        fprintf('\tGRR = %f\n', grr);

        tall = 0;
        for w = 1:q
            if(h_gram(w) > tall)
                tall = h_gram(w);
            end
        end
        bar(x_axis,h_gram);
        ylim([0 tall*2]);
        
        if(isnan(str2double(test_data(whichTest,4))))       % determine and plot datasheet limits
            % no low limit
        else
            plot([low,low],[0,tall*2],'LineWidth',3,'LineStyle','-','color','r');
        end
        if(isnan(str2double(test_data(whichTest,3))))
            % no upper limit
        else
            plot([high,high],[0,tall*2],'LineWidth',3,'LineStyle','-','color','r');
        end
        
        plot([mu,mu],[tall*2*0.65,tall*2*0.95],'LineWidth',2,'LineStyle','-','color','k');
        plot([mu+sigma,mu+sigma],[tall*2*0.6,tall*2],'LineWidth',2,'LineStyle','-','color','b');     %plots standard deviation on the plots
        plot([mu-sigma,mu-sigma],[tall*2*0.6,tall*2],'LineWidth',2,'LineStyle','-','color','b');
        plot([mu-sigma,mu+sigma],[tall*2*0.8,tall*2*0.8],'LineWidth',1,'LineStyle','-','color','b');
        
    end
   
    clear all
       
    fprintf('\n');
    
    
  