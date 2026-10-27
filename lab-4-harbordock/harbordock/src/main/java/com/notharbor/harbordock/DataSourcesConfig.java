package com.notharbor.harbordock;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

import org.springframework.boot.jdbc.DataSourceBuilder;

/**
 * Two database logins, two connection pools. The search login was the
 * product one; the stats login arrived with the console widgets and
 * carries its own grants, including the vault the search side was
 * never supposed to see.
 */
@Configuration
public class DataSourcesConfig {

    @Bean
    @ConfigurationProperties(prefix = "spring.datasource.search")
    public DataSource searchDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    @ConfigurationProperties(prefix = "spring.datasource.stats")
    public DataSource statsDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    public JdbcTemplate jdbcSearch(DataSource searchDataSource) {
        return new JdbcTemplate(searchDataSource);
    }

    @Bean
    public JdbcTemplate jdbcStats(DataSource statsDataSource) {
        return new JdbcTemplate(statsDataSource);
    }
}