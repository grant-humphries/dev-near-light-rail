--Washington County has provided development year data (year built) for tax
--lots that is either out of data or does not exist in RLIS, this script adds
--that information to RLIS tax lots

alter table :wash_yr_tlno add constraint wyt_tlid_ix unique (tlno);
alter table :wash_yr_tlno add constraint wyt_rno_ix unique (account);

--rno is the consecutive alpha-numeric characters thaht begin :id_col
create temp table wash_yr_rno as
    select substring(:id_col, '^\w+') as rno, max(:yr_col) as yr_built
    from :wash_yr_seg
    group by rno;

alter table wash_yr_rno add primary key (rno);

--Group by rno to have a single entry for each taxlot, the most recent
--year will be used as the development date
drop table if exists wash_co_years cascade;
create table wash_co_years as
    select
        coalesce(r.rno, t.account) as rno,
        t.tlno as tlid,
        greatest(r.yr_built, t.yr_built::int) as yearbuilt
    from wash_yr_rno r
        full join :wash_yr_tlno t
        on r.rno = t.account;

alter table wash_co_years add yid serial primary key;
create index wash_co_rno_ix on wash_co_years using BTREE (rno);
create index wash_co_tlid_ix on wash_co_years using BTREE (tlid);
create index wash_co_built_ix on wash_co_years using BTREE (yearbuilt);
vacuum analyze wash_co_years;

--Testing verifies that either an 'rno' or 'tlid' join between the
--these two tables produces a valid match
update developed_taxlots as dt
    set yearbuilt = wy.yearbuilt
    from wash_co_years wy
    where (dt.tlid = wy.tlid or dt.rno = wy.rno)
        and dt.yearbuilt < wy.yearbuilt;
