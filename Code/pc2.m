%% pc2.m  —— 纸箱-左右方向 波束图
% 半圆极坐标网格 + 包络曲线（可选斜线填充）
clear; clc; close all;

%% ========== 1) 输入数据（单位：cm）==========
y_cm  = [0 10 50 90 130 170 210 250 290 330 370 400 440];
xL_cm = [0 -15 -30 -39 -38 -25 -30 -20 -18 -13 -18 -16 -8];
xR_cm = [0  10  24  35  30  29  32  28  27  25  24  28 24];

%% ========== 2) 单位换算：cm -> m ==========
cm2m = 0.01;
y  = y_cm  * cm2m;   % 前向距离(米)
xL = xL_cm * cm2m;   % 左边界(米)
xR = xR_cm * cm2m;   % 右边界(米)

%% ========== 3) 构造闭合包络多边形 ==========
[xpoly, ypoly] = buildEnvelope(y, xL, xR);

%% ========== 4) 画半圆极坐标网格 ==========
Rmax = 10; % 想让图更“撑满”可以改成 5 或 3
figure('Color','w');
ax = axes; hold(ax,'on'); axis(ax,'equal');
drawHalfPolarGrid(ax, Rmax, 1, 0.5, 10, 5);  % (Rmax, r主, r次, theta主, theta次)

%% ========== 5) 画包络（填充/仅边界） ==========
doFill = true;
if doFill
    patch(ax, xpoly, ypoly, [0.92 0.92 0.92], 'EdgeColor','k', 'LineWidth', 2);
else
    plot(ax, xpoly, ypoly, 'k', 'LineWidth', 2);
end

%% ========== 6) 标题与单位 ==========
title(ax, '纸箱波束图', 'FontSize', 11);
text(ax, Rmax*0.78, -Rmax*0.12, '（单位：米）', ...
    'HorizontalAlignment','left', 'FontSize', 9);

%% ========== 7) 可选：斜线网纹填充（更像原图） ==========
% hatchInPolygon(ax, xpoly, ypoly, 45, 0.10);  % 角度45°，间距0.10m（越小越密）
% plot(ax, xpoly, ypoly, 'k', 'LineWidth', 2);  % 重新描边更清晰


%% ======================= 本地函数区（每个函数都必须end） =======================

function [xpoly, ypoly] = buildEnvelope(y, xL, xR)
% 把左右边界拼成闭合多边形：
% 右边界：y递增；左边界：y递减反向拼回
    y  = y(:);  xL = xL(:);  xR = xR(:);

    ok = isfinite(y) & isfinite(xL) & isfinite(xR);
    y = y(ok); xL = xL(ok); xR = xR(ok);

    % 按y排序，避免折线乱连
    [y, idx] = sort(y);
    xL = xL(idx);
    xR = xR(idx);

    xpoly = [xR; flipud(xL)];
    ypoly = [y;  flipud(y)];

    % 闭合
    if xpoly(1) ~= xpoly(end) || ypoly(1) ~= ypoly(end)
        xpoly(end+1) = xpoly(1);
        ypoly(end+1) = ypoly(1);
    end
end

function drawHalfPolarGrid(ax, Rmax, rMajorStep, rMinorStep, thMajorStep, thMinorStep)
% 自绘半圆极坐标网格（0°在上，左右±90°），底部对称半径刻度
    axes(ax); %#ok<LAXES>
    xlim(ax, [-Rmax Rmax]);
    ylim(ax, [0 Rmax]);

    majorC = [0.55 0.55 0.55];
    minorC = [0.80 0.80 0.80];
    th = deg2rad(-90:0.5:90);

    % 圆弧（半径网格）
    for rr = 0:rMinorStep:Rmax
        x = rr .* sin(th);
        y = rr .* cos(th);
        isMajor = abs(mod(rr, rMajorStep)) < 1e-10;
        plot(ax, x, y, 'Color', tern(isMajor, majorC, minorC), ...
            'LineWidth', tern(isMajor, 0.9, 0.6));
    end

    % 径向线（角度网格）
    for t = -90:thMinorStep:90
        thh = deg2rad(t);
        rr = [0 Rmax];
        x = rr .* sin(thh);
        y = rr .* cos(thh);
        isMajor = abs(mod(t, thMajorStep)) < 1e-10;
        plot(ax, x, y, 'Color', tern(isMajor, majorC, minorC), ...
            'LineWidth', tern(isMajor, 0.9, 0.6));
    end

    % 外圈 + 底边
    plot(ax, Rmax.*sin(th), Rmax.*cos(th), 'k', 'LineWidth', 1.2);
    plot(ax, [-Rmax Rmax], [0 0], 'k', 'LineWidth', 1.2);

    % 角度标注（外圈，左右显示 0~90）
    for t = -90:thMajorStep:90
        thh = deg2rad(t);
        rt  = Rmax * 1.06;
        xt  = rt * sin(thh);
        yt  = rt * cos(thh);
        lab = sprintf('%d°', abs(t));
        if t==0, lab = '0°'; end
        text(ax, xt, yt, lab, 'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', 'FontSize', 9);
    end

    % 半径刻度（底边左右对称）
    yoff = -Rmax * 0.04;
    for rr = 0:rMajorStep:Rmax
        text(ax, -rr, yoff, sprintf('%g', rr), ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
        if rr ~= 0
            text(ax, rr, yoff, sprintf('%g', rr), ...
                'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', 9);
        end
    end

    ax.XTick = []; ax.YTick = [];
    box(ax,'off');
end

function hatchInPolygon(ax, xpoly, ypoly, angleDeg, spacing)
% 多边形内斜线填充（网纹）
    xpoly = xpoly(:); ypoly = ypoly(:);

    a = deg2rad(angleDeg);
    R  = [cos(a) -sin(a); sin(a) cos(a)];
    Ri = [cos(-a) -sin(-a); sin(-a) cos(-a)];

    % 旋转到网纹坐标系
    P = [xpoly ypoly]*Ri';
    xr = P(:,1); yr = P(:,2);

    xmin = min(xr); xmax = max(xr);
    ymin = min(yr); ymax = max(yr);

    % 扫描线（在旋转坐标系中是水平线）
    yLines = (floor(ymin/spacing)-1 : ceil(ymax/spacing)+1) * spacing;

    dx = spacing/6;                 % 采样步进，越小越细但更耗时
    xs = (xmin:dx:xmax).';

    for yy = yLines
        X = xs;
        Y = yy * ones(size(X));

        % 逆旋转回原坐标系
        XY = [X Y]*R';
        xw = XY(:,1); yw = XY(:,2);

        % ✅ 正确的 inpolygon 写法
        inside = inpolygon(xw, yw, xpoly, ypoly);

        idx = find(inside);
        if isempty(idx), continue; end

        % 按连续段绘制（断点处不连）
        breaks = [1; find(diff(idx)>1)+1; numel(idx)+1];
        for k = 1:numel(breaks)-1
            seg = idx(breaks(k):breaks(k+1)-1);
            plot(ax, xw(seg), yw(seg), 'k', 'LineWidth', 0.8);
        end
    end
end

function out = tern(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
