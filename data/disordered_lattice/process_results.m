close all
clear all

test = {'vexcl_1gpu', 'vexcl_2gpu', 'vexcl_cpu', ...
	'viennacl_gpu', 'viennacl_cpu'};

lgnd = {'VexCL 1 GPU', 'VexCL 2 GPU', 'VexCL 3 GPU', ...
	'ViennaCL GPU', 'ViennaCL CPU'};

style = {'ro-', 'rs-', 'rd-', ...
	 'bo-', 'bd-'};

figure(1)
set(gcf, 'position', [50, 50, 1000, 500]);

subplot(1, 2, 1);
set(gca, 'FontSize', 10);
subplot(1, 2, 2);
set(gca, 'FontSize', 10);

idx = 0;
for t = test
    idx = idx + 1;
    data = load([cell2mat(t) '.dat']);
    avg = [];

    n = unique(data(:,1))';
    for i = n
	I = find(data(:,1) == i);
	time = sum(data(I,2)) / length(I);
	avg = [avg time];
    end

    if idx == 1
	ref_avg = avg;
    end

    subplot(1, 2, 1);
    loglog(n, avg, style{idx}, 'markersize', 4, 'markerfacecolor', 'w');
    hold on

    subplot(1, 2, 2);
    loglog(n, avg ./ ref_avg(1:length(avg)), style{idx}, 'markersize', 4, 'markerfacecolor', 'w');
    hold on
end

subplot(1, 2, 1);
xlim([5e0 1e4])
%ylim([1e-1 1e5])
set(gca, 'xtick', [1e2 1e3 1e4 1e5 1e6 1e7])
xlabel('N');
ylabel('T (sec)');
legend(lgnd, 'location', 'NorthWest');
legend boxoff
axis square

subplot(1, 2, 2);
xlim([5e0 1e4])
set(gca, 'xtick', [1e2 1e3 1e4 1e5 1e6 1e7])
xlabel('N');
ylabel('T / T(VexCL 1 GPU)');
axis square

print('-depsc', 'disordered_lattice.eps');